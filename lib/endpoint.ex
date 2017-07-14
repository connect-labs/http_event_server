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


  plug Plug.Parsers, parsers: [:json],
                     pass:  ["text/*"],
                     json_decoder: Poison
  plug(:set_event_module)
  plug(:match)
  plug(:dispatch)

  defp set_event_module(%{private: %{otp_app: otp_app}} = conn, _opts) do
    conn
    |> put_private(:event_module, Application.get_env(otp_app, :http_event_module))
  end
  defp set_event_module(conn, _opts), do: conn

  match "/test/:task" do
    run_tasks(conn, task)
  end

  match "/:task" do
    case HTTPEventServer.Authorize.authorize(conn) do
      %Plug.Conn{state: :sent} = conn -> conn
      conn -> run_tasks(conn, task)
    end
  end

  match "" do
    send_event_response({:error, error_response("nil")}, conn, "nil")
  end

  defp run_tasks(conn, task) do
    Logger.debug "Running event", [event: task]
    send_event_response(attempt_to_send_task(conn.private, task, conn.body_params), conn, task)
  end

  defp send_unless(%{state: :sent} = conn, _code, _message), do: conn

  defp send_unless(conn, code, message) when is_binary(message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(code, message)
  end

  defp send_unless(conn, code, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(code, Poison.encode!(message))
  end


  defp attempt_to_send_task(opts, task, %{"_json" => data}), do: attempt_to_send_task(opts, task, data)
  defp attempt_to_send_task(%{event_module: event_module}, task, data) do
    event_module.handle(task, data)
  end

  defp attempt_to_send_task(opts, task, data) do
    case Application.get_env(:http_event_server, :event_module) do
      nil -> {:http_event_server_error, "No event module defined"}
      module -> attempt_to_send_task(%{event_module: module}, task, data)
    end
  end

  defp send_event_response(:not_defined, %{params: %{"task" => event}} = conn, _) do
    send_unless(conn, 500, "Event '#{event}' not captured")
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
      "Event '#{event}' not captured"
    end
  end
end
