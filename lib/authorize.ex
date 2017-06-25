defmodule HTTPEventServer.Authorize do
  @moduledoc """
  Authorizes a request by checking if the Authorization Bearer Header contains
  the token specifiec in its config.
  """

  import Plug.Conn
  require Logger

  @doc """
  Returns `Plug.Conn` that has either already returned a response of 401 or not at all.
  This will look in the conn's HEADERS and validates the Authorization Bearer Token is the
  same as in the config
  """
  def authorize(conn) do
    case find_token(conn) do
      {:ok, :valid} -> conn
      _otherwise   -> auth_error!(conn)
    end
  end

  defp find_token(conn) do
    with {:ok, req_token} <- get_token(conn),
      true <- validate_token(req_token),
    do: {:ok, :valid}
  end

  defp get_token(conn) do
    get_token_from_header(get_req_header(conn, "authorization"))
  end

  defp get_token_from_header(["Bearer " <> token]) do
    {:ok, String.replace(token, ~r/(\"|\')/, "")}
  end

  defp get_token_from_header(_non_token_header) do
    :error
  end

  defp validate_token(token) do
    Application.get_env(:http_event_server, :api_token) == token
  end

  defp auth_error!(conn) do
    Logger.debug "Invalid Token"
    conn
    |> put_status(:unauthorized)
    |> send_resp(401, Poison.encode!(%{error: "Invalid Token"}))
  end
end
