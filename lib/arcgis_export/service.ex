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
      |> validate_required([:name, :type, :fields, :max_record_count])

    if changeset.valid?, do: {:ok, apply_changes(changeset)}, else: {:error, :unexpected_response}
  end

  def changeset(service, params \\ %{}) do
    service
    |> cast(params, [:id, :name, :type, :description, :fields, :max_record_count])
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

  defp random, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32)

  def to_file(service) do
    file = Path.join(System.tmp_dir!(), random() <> ".csv")

    service
    |> stream!()
    |> Stream.chunk_every(service.max_record_count)
    |> Stream.map(fn x ->
      Logger.info("next")
      x
    end)
    |> Stream.into(File.stream!(file))
    |> Stream.run()

    Logger.info(file, label: "DOOOOOOOOOOOOOOOOOOONE")
  end

  #

  # def build_csv(%Service{} = service) do
  #

  #   Logger.info(file)

  #   service
  #   |> get_ids()

  #   with {:ok, records} <- get_records(service) do
  #     header =
  #       service.fields
  #       |> Enum.map(fn %{"name" => name} -> name end)

  #     [header]
  #     |> Stream.concat(records)
  #     |> CSV.dump_to_stream()
  #     |> Stream.into(File.stream!(file))
  #     |> Stream.run()

  #     {:ok, Map.put(service, :csv_path, file)}
  #   end
  # end

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
                outFields: "*",
                f: "geojson"
              ],
              timeout: 30_000,
              recv_timeout: 30_000
            )
            |> Map.get(:body)
            |> Jason.decode!()
            |> Map.get("features")
            |> Enum.map(fn %{"properties" => properties} ->
              fields
              |> Enum.map(fn %{"name" => name} -> Map.get(properties, name, "") end)
            end)

          {result, Map.put(acc, :ranges, rest)}
      end,
      fn _ -> :ok end
    )

    # case HTTPoison.get(Path.join(url, "query"), [],
    #        params: [where: "1=1", outFields: "*", f: "geojson"]
    #      ) do
    #   {:ok, %{body: body}} ->
    #     result =
    #       Jason.decode!(body)
    #       |> Map.get("features")
    #       |> Enum.map(fn %{"properties" => properties} ->
    #         fields
    #         |> Enum.map(fn %{"name" => name} -> Map.get(properties, name, "") end)
    #       end)

    #     {:ok, result}

    #   {:error, _} ->
    #     {:error, "failed on pulling data"}
    # end
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
