if Application.fetch_env!(:swoosh, :api_client) == Swoosh.ApiClient.Finch do
  Application.put_env(:swoosh, :finch_name, Swoosh.Test.Finch)
  Finch.start_link(name: Swoosh.Test.Finch)
end

if :mailpit in ExUnit.configuration()[:include] do
  mailpit_available? =
    case Req.get("http://localhost:8025/api/v1/info", retry: false) do
      {:ok, %{status: 200}} -> true
      {:error, %{reason: :econnrefused}} -> false
    end

  unless mailpit_available? do
    Mix.shell().error("""
    To enable Mailpit tests, start the local container with the following command:

        docker run -d --rm -p 1025:1025 -p 8025:8025 --name mailpit axllent/mailpit

    And stop it once done:

        docker stop mailpit
    """)
  end
end

ExUnit.start()
ExUnit.configure(exclude: [:integration, :mailpit])

Application.ensure_all_started(:bypass)
