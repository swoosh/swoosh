defmodule Swoosh.ApiClient do
  @user_agent {"User-Agent", "swoosh/#{Swoosh.version()}"}

  def post(url, headers, body, %Swoosh.Email{} = email) do
    hackney_options = email.private[:hackney_options] || []

    :hackney.post(
      url,
      [@user_agent | headers],
      body,
      [:with_body | hackney_options]
    )
  end
end
