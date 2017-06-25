defmodule HTTPEventServer.Endpoint do
  @moduledoc """
  Forward requests to this router by `forward "/message", to: Messenger.Router`.  This will capture
  POST requests on the `/message/:task` route calling the task specified.  In your config, you will need
  to add the following options:

  ```
  config :http_event_server,
    api_token: System.get_env("API_TOKEN"),
    task_module: YourTaskModule
  ```

  Optionally, you can configure the response when a task is not found with the `fail_on_no_event_found`
  config options.  Setting it to true will return a 500 error

  You will need to define a task module that has a `handle(message, data)` function.  This function
  needs to return either {:ok, %{}} or {:error, %{}}.  If not, this will automatically return a 500 error.

  You can send messages to this router by sending a `POST` request with a `JSON` body and an
  `Authorization Bearer token` header.

  """
  use Plug.Router
  require Logger

  plug(Plug.Logger)


  plug Plug.Parsers, parsers: [:json],
                     pass:  ["text/*"],
                     json_decoder: Poison

  plug(:match)
  plug(:dispatch)

  match "/:task" do
    case HTTPEventServer.Authorize.authorize(conn) do
      %Plug.Conn{state: :sent} -> conn
      conn ->
        result = with :http_event_server_error <- attempt_to_send_task(task, conn.body_params, conn.method),
                      :http_event_server_error <- attempt_to_send_task(task, conn.body_params, false),
                      do: error_response(task)
        send_event_response(result, conn, task)
    end
  end

  defp send_unless(%{state: :sent} = conn, _code, _message), do: conn

  defp send_unless(conn, code, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(code, Poison.encode!(message))
  end


  defp attempt_to_send_task(task, data, false) do
    try do
      Application.get_env(:http_event_server, :event_module).handle(task, data)
    rescue
      UndefinedFunctionError -> :http_event_server_error
    end
  end

  defp attempt_to_send_task(task, data, method) do
    try do
      Application.get_env(:http_event_server, :event_module).handle(task, data, String.upcase(method))
    rescue
      UndefinedFunctionError -> :http_event_server_error
    end
  end

  defp send_event_response({:error, resp}, conn, _) do
    send_unless(conn, 500, resp)
  end

  defp send_event_response({:ok, resp}, conn, _) do
    send_unless(conn, 200, resp)
  end

  defp send_event_response({:http_event_server_error, resp}, conn, task) do
    send_unless(conn, 500, %{error: "Invalid return value from task", task: task, response: resp, method: conn.method})
  end

  defp send_event_response(resp, conn, _) do
    send_unless(conn, 200, resp)
  end

  defp error_response(event) do
    if Application.get_env(:http_event_server, :fail_on_no_event_found) do
      {:http_event_server_error, "Event \"#{inspect event}\" not captured"}
    else
      :ok
    end
  end
end
