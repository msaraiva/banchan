defmodule BanchanWeb.HomeLive do
  @moduledoc """
  Banchan Homepage
  """
  use BanchanWeb, :surface_view

  alias Banchan.Components.Layout

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    {:ok, assign(socket, query: "", results: %{})}
  end

  @impl true
  def render(assigns) do
    ~F"""
    <Layout current_user={@current_user} flashes={@flash}>
      I guess I'm home?
    </Layout>
    """
  end
end
