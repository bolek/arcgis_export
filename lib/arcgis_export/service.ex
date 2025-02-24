defmodule ArcgisExport.Service do
  alias __MODULE__
  require Logger
  use Ecto.Schema

  import Ecto.Changeset

  alias NimbleCSV.RFC4180, as: CSV

  @primary_key false
  embedded_schema do
    field(:url, :string)
    field :id, :integer
    field :max_record_count, :integer
    field :name, :string
    field :type, :string
    field :description, :string
    field :fields, {:array, :map}
    field :total_records, :integer
    field :csv_path, :string
    field :source_spatial_reference, :map
  end

  def new(url) do
    with {:ok, url} <- valid_url?(url),
         {:ok, %{body: body}} <-
           HTTPoison.get(url, [{"Content-Type", "text/plain;charset=UTF-8"}], params: [f: "pjson"]),
         {:ok, service_params} <- Jason.decode(body) do
      ArcgisExport.Service.build(
        url,
        service_params |> Recase.Enumerable.convert_keys(&Recase.to_snake/1)
      )
    else
      error ->
        IO.inspect(error)
        error
    end
  end

  defp valid_url?(url) do
    result =
      url
      |> String.trim()
      |> String.match?(~r(/arcgis/rest/services/.*/[0-9]+$))

    if result, do: {:ok, url}, else: {:error, :invalid_url}
  end

  def build(_, %{"error" => %{"code" => 500}}), do: {:error, :inexistent}

  def build(url, params) do
    changeset =
      %ArcgisExport.Service{url: url}
      |> changeset(params)
      |> validate_required([:name, :type, :fields, :max_record_count, :source_spatial_reference])

    if changeset.valid?,
      do: {:ok, apply_changes(changeset)},
      else: {:error, :unexpected_response}
  end

  def changeset(service, params \\ %{}) do
    service
    |> cast(params, [
      :id,
      :name,
      :type,
      :description,
      :fields,
      :max_record_count,
      :source_spatial_reference
    ])
  end

  def count(%Service{url: url} = service) do
    case HTTPoison.get(Path.join(url, "query"), [],
           params: [where: "1=1", returnCountOnly: true, f: "pjson"]
         ) do
      {:ok, %{body: body}} ->
        {:ok, Map.put(service, :total_records, Map.get(Jason.decode!(body), "count"))}

      {:error, _} ->
        {:error, "unable to retrieve count"}
    end
  end

  def stream!(%Service{} = service) do
    headers =
      service.fields
      |> Enum.map(fn %{"name" => name} -> name end)

    [headers]
    |> Stream.concat(get_records(service))
    |> CSV.dump_to_stream()
  end

  def get_records(%Service{} = service) do
    Stream.resource(
      fn ->
        {:ok, {object_id_field_name, ranges}} = get_ids(service)
        %{service: service, object_id_field_name: object_id_field_name, ranges: ranges}
      end,
      fn
        %{ranges: []} = acc ->
          {:halt, acc}

        %{
          service: %{url: url, fields: fields},
          object_id_field_name: object_id_field_name,
          ranges: [range | rest]
        } = acc ->
          result =
            HTTPoison.get!(
              Path.join(url, "query?where=#{range_condition(object_id_field_name, range)}"),
              [],
              params: [
                returnGeometry: true,
                outFields: "*",
                f: "geojson"
              ],
              timeout: 30_000,
              recv_timeout: 30_000
            )
            |> Map.get(:body)
            |> Jason.decode!()
            |> Map.get("features")
            |> Enum.map(fn %{"properties" => properties, "geometry" => geometry} ->
              fields
              |> Enum.map(fn
                %{"type" => "esriFieldTypeGeometry"} ->
                  case Geo.JSON.decode(geometry) do
                    {:ok, parsed_geometry} ->
                      parsed_geometry
                      |> Map.put(:srid, Map.get(service.source_spatial_reference, "latest_wkid"))
                      |> Geo.WKT.encode!()

                    _ ->
                      ''
                  end

                %{"name" => name} ->
                  Map.get(properties, name, "")
              end)
            end)

          {result, Map.put(acc, :ranges, rest)}
      end,
      fn _ -> :ok end
    )
  end

  defp range_condition(field_name, %{from: from, to: nil}),
    do: URI.encode("#{field_name}>=#{from}")

  defp range_condition(field_name, %{from: from, to: to}),
    do: "#{URI.encode("#{field_name}>=#{from}")}+AND+#{URI.encode("#{field_name}<=#{to}")}"

  def get_ids(%Service{max_record_count: max, url: url}) do
    case HTTPoison.get(Path.join(url, "query"), [],
           params: [where: "1=1", returnIdsOnly: true, f: "pjson"],
           timeout: 30_000,
           recv_timeout: 30_000
         ) do
      {:ok, %{body: body}} ->
        %{"objectIdFieldName" => object_id_field_name, "objectIds" => object_ids} =
          Jason.decode!(body)

        ranges =
          object_ids
          |> Enum.sort()
          |> Enum.reduce([], fn
            obj, [%{from: from, to: nil, count: count} | rest] ->
              if count + 1 == max,
                do: [%{from: from, to: obj, count: max} | rest],
                else: [%{from: from, to: nil, count: count + 1} | rest]

            obj, acc ->
              [%{from: obj, to: nil, count: 1} | acc]
          end)

        {:ok, {object_id_field_name, ranges |> Enum.reverse()}}

      {:error, error} ->
        Logger.error(inspect(error))
        {:error, "unable to get ids"}
    end
  end
end
