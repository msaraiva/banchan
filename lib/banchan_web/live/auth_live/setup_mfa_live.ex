defmodule BanchanWeb.SetupMfaLive do
  @moduledoc """
  Account Setup MFA
  """
  use BanchanWeb, :surface_view

  alias Surface.Components.Form

  alias Banchan.Accounts

  alias BanchanWeb.AuthLive.Components.AuthLayout
  alias BanchanWeb.Components.Form.{Submit, TextInput}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user.totp_secret do
      totp_uri =
        NimbleTOTP.otpauth_uri("Banchan:#{user.email}", user.totp_secret, issuer: "Banchan")

      secret = Base.encode32(user.totp_secret, padding: false)
      qr_code = QRCode.create!(totp_uri)
      svg = qr_code |> QRCode.Svg.to_base64()
      totp_svg = "data:image/svg+xml;base64,#{svg}"

      {:ok,
       socket |> assign(qrcode_svg: totp_svg, secret: secret, totp_activated: user.totp_activated)}
    else
      {:ok, socket |> assign(qrcode_svg: nil, secret: nil, totp_activated: false)}
    end
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, socket |> assign(uri: uri)}
  end

  @impl true
  def handle_event("setup_mfa", _, socket) do
    user = socket.assigns.current_user

    if user.totp_activated == true do
      socket =
        socket
        |> put_flash(:info, "TOTP already activated")
        |> redirect(to: Routes.setup_mfa_path(socket, :edit))

      {:noreply, socket}
    end

    case Accounts.generate_totp_secret(user) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "MFA token generated successfully")
          |> redirect(to: Routes.setup_mfa_path(socket, :edit))

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("deactivate_mfa", %{"user" => u}, socket) do
    user = socket.assigns.current_user

    if user.totp_activated do
      case Accounts.deactivate_totp(user, u["password"]) do
        {:ok, _} ->
          socket =
            socket
            |> put_flash(:info, "MFA token deactivated")
            |> push_redirect(to: Routes.setup_mfa_path(socket, :edit))

          {:noreply, socket}

        {:error, :invalid_password} ->
          socket =
            socket
            |> put_flash(:error, "Invalid password")
            |> push_redirect(to: Routes.setup_mfa_path(socket, :edit))

          {:noreply, socket}
      end
    else
      socket =
        socket
        |> put_flash(:error, "TOTP not activated")
        |> redirect(to: Routes.setup_mfa_path(socket, :edit))

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("confirm_mfa", val, socket) do
    user = socket.assigns.current_user

    if user.totp_activated do
      socket =
        socket
        |> put_flash(:info, "TOTP already activated")
        |> redirect(to: Routes.setup_mfa_path(socket, :edit))

      {:noreply, socket}
    end

    case Accounts.activate_totp(
           user,
           val["user"]["token"]
         ) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "MFA token activated")
          |> redirect(to: Routes.setup_mfa_path(socket, :edit))

        {:noreply, socket}

      {:error, :invalid_token} ->
        socket =
          socket
          |> put_flash(:error, "Invalid MFA token")
          |> redirect(to: Routes.setup_mfa_path(socket, :edit))

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~F"""
    <AuthLayout uri={@uri} current_user={@current_user} flashes={@flash}>
      {#if @qrcode_svg && !@totp_activated}
        <h1 class="text-2xl">Your QR Code</h1>
        <br>
        <img src={@qrcode_svg} style="width: 200px; padding: 10px; background-color: white;">
        <br>
        No QR code reader? Input the following value in your MFA app:
        <br>
        {@secret}
        <div class="divider" />
        <h1 class="text-2xl">Confirm MFA 6-digit OTP</h1>
        <Form class="flex flex-col gap-4" for={:user} submit="confirm_mfa">
          <TextInput name={:token} label="One Time Password" opts={required: true} />
          <Submit class="w-full" label="Activate" />
        </Form>
      {#elseif @qrcode_svg && @totp_activated}
        <h1 class="text-2xl">You have MFA enabled</h1>
        <Form for={:user} submit="deactivate_mfa">
          <TextInput name={:password} label="Current Password" opts={required: true, type: "password"} />
          <Submit class="w-full btn-error" label="Deactivate MFA" />
        </Form>
      {#else}
        <h1 class="text-2xl">MFA Setup</h1>
        <Form for={:user} submit="setup_mfa">
          You do not have MFA enabled.
          <Submit class="w-full" label="Set up MFA" />
        </Form>
      {/if}
    </AuthLayout>
    """
  end
end
