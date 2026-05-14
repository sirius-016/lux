defmodule Lux.Lenses.TelegramLens.Types do
  @moduledoc """
  Type definitions for Telegram Bot API entities.

  These types mirror the Telegram Bot API types and are used for
  documentation and dialyzer type checking.
  """

  # --------------------------------------------------------------------------
  # User-Facing Types
  # --------------------------------------------------------------------------

  @type user :: %{
    required(:id) => integer,
    optional(:is_bot) => boolean,
    optional(:first_name) => String.t(),
    optional(:last_name) => String.t(),
    optional(:username) => String.t(),
    optional(:language_code) => String.t()
  }

  @type chat :: %{
    required(:id) => integer,
    required(:type) => String.t(),  # "private", "group", "supergroup", "channel"
    optional(:title) => String.t(),
    optional(:username) => String.t(),
    optional(:first_name) => String.t(),
    optional(:last_name) => String.t(),
    optional(:description) => String.t(),
    optional(:invite_link) => String.t(),
    optional(:pinned_message) => message(),
    optional(:permissions) => chat_permissions(),
    optional(:slow_mode_delay) => integer,
    optional(:sticker_set_name) => String.t(),
    optional(:can_set_sticker_set) => boolean
  }

  @type chat_permissions :: %{
    optional(:can_send_messages) => boolean,
    optional(:can_send_media_messages) => boolean,
    optional(:can_send_polls) => boolean,
    optional(:can_send_other_messages) => boolean,
    optional(:can_add_web_page_previews) => boolean,
    optional(:can_change_info) => boolean,
    optional(:can_invite_users) => boolean,
    optional(:can_pin_messages) => boolean
  }

  @type message :: %{
    required(:message_id) => integer,
    required(:date) => integer,
    required(:chat) => chat(),
    optional(:from) => user(),
    optional(:forward_from) => user(),
    optional(:forward_from_chat) => chat(),
    optional(:forward_from_message_id) => integer,
    optional(:forward_signature) => String.t(),
    optional(:forward_date) => integer,
    optional(:reply_to_message) => message(),
    optional(:via_bot) => user(),
    optional(:edit_date) => integer,
    optional(:media_group_id) => String.t(),
    optional(:author_signature) => String.t(),
    optional(:text) => String.t(),
    optional(:entities) => [message_entity()],
    optional(:caption_entities) => [message_entity()],
    optional(:audio) => audio(),
    optional(:document) => document(),
    optional(:animation) => animation(),
    optional(:game) => game(),
    optional(:photo) => [photo_size()],
    optional(:sticker) => sticker(),
    optional(:video) => video(),
    optional(:video_note) => video_note(),
    optional(:voice) => voice(),
    optional(:caption) => String.t(),
    optional(:contact) => contact(),
    optional(:location) => location(),
    optional(:venue) => venue(),
    optional(:poll) => poll(),
    optional(:new_chat_members) => [user()],
    optional(:new_chat_title) => String.t(),
    optional(:new_chat_photo) => [photo_size()],
    optional(:delete_chat_photo) => boolean,
    optional(:group_chat_created) => boolean,
    optional(:supergroup_chat_created) => boolean,
    optional(:channel_chat_created) => boolean,
    optional(:migrate_to_chat_id) => integer,
    optional(:migrate_from_chat_id) => integer,
    optional(:pinned_message) => message(),
    optional(:invoice) => invoice(),
    optional(:successful_payment) => successful_payment(),
    optional(:connected_website) => String.t(),
    optional(:passport_data) => passport_data(),
    optional(:reply_markup) => inline_keyboard_markup()
  }

  @type message_entity :: %{
    required(:type) => String.t(),
    required(:offset) => integer,
    required(:length) => integer,
    optional(:url) => String.t(),
    optional(:user) => user()
  }

  @type photo_size :: %{
    required(:file_id) => String.t(),
    required(:file_unique_id) => String.t(),
    required(:width) => integer,
    required(:height) => integer,
    optional(:file_size) => integer
  }

  @type audio :: %{
    required(:file_id) => String.t(),
    required(:file_unique_id) => String.t(),
    required(:duration) => integer,
    optional(:performer) => String.t(),
    optional(:title) => String.t(),
    optional(:file_name) => String.t(),
    optional(:mime_type) => String.t(),
    optional(:file_size) => integer
  }

  @type document :: %{
    required(:file_id) => String.t(),
    required(:file_unique_id) => String.t(),
    optional(:thumbnail) => photo_size(),
    optional(:file_name) => String.t(),
    optional(:mime_type) => String.t(),
    optional(:file_size) => integer
  }

  @type animation :: %{
    required(:file_id) => String.t(),
    required(:file_unique_id) => String.t(),
    required(:width) => integer,
    required(:height) => integer,
    required(:duration) => integer,
    optional(:thumbnail) => photo_size(),
    optional(:file_name) => String.t(),
    optional(:mime_type) => String.t(),
    optional(:file_size) => integer
  }

  @type video :: %{
    required(:file_id) => String.t(),
    required(:file_unique_id) => String.t(),
    required(:width) => integer,
    required(:height) => integer,
    required(:duration) => integer,
    optional(:thumbnail) => photo_size(),
    optional(:mime_type) => String.t(),
    optional(:file_size) => integer
  }

  @type video_note :: %{
    required(:file_id) => String.t(),
    required(:file_unique_id) => String.t(),
    required(:length) => integer,
    required(:duration) => integer,
    optional(:thumbnail) => photo_size(),
    optional(:file_size) => integer
  }

  @type voice :: %{
    required(:file_id) => String.t(),
    required(:file_unique_id) => String.t(),
    required(:duration) => integer,
    optional(:mime_type) => String.t(),
    optional(:file_size) => integer
  }

  @type contact :: %{
    required(:phone_number) => String.t(),
    required(:first_name) => String.t(),
    optional(:last_name) => String.t(),
    optional(:user_id) => integer,
    optional(:vcard) => String.t()
  }

  @type location :: %{
    required(:longitude) => float,
    required(:latitude) => float,
    optional(:horizontal_accuracy) => float,
    optional(:live_period) => integer,
    optional(:heading) => integer,
    optional(:proximity_alert_radius) => integer
  }

  @type venue :: %{
    required(:location) => location(),
    required(:title) => String.t(),
    required(:address) => String.t(),
    optional(:foursquare_id) => String.t(),
    optional(:foursquare_type) => String.t(),
    optional(:google_place_id) => String.t(),
    optional(:google_place_type) => String.t()
  }

  @type poll :: %{
    required(:id) => String.t(),
    required(:question) => String.t(),
    required(:options) => [poll_option()],
    required(:total_voter_count) => integer,
    required(:is_closed) => boolean,
    required(:is_anonymous) => boolean,
    required(:type) => String.t(),
    required(:allows_multiple_answers) => boolean,
    optional(:correct_option_id) => integer,
    optional(:explanation) => String.t(),
    optional(:explanation_entities) => [message_entity()],
    optional(:open_period) => integer,
    optional(:close_date) => integer
  }

  @type poll_option :: %{
    required(:text) => String.t(),
    required(:voter_count) => integer
  }

  @type game :: %{
    required(:title) => String.t(),
    required(:description) => String.t(),
    required(:photo) => [photo_size()],
    optional(:text) => String.t(),
    optional(:text_entities) => [message_entity()],
    optional(:animation) => animation()
  }

  @type invoice :: %{
    required(:title) => String.t(),
    required(:description) => String.t(),
    required(:start_parameter) => String.t(),
    required(:currency) => String.t(),
    required(:total_amount) => integer
  }

  @type successful_payment :: %{
    required(:currency) => String.t(),
    required(:total_amount) => integer,
    required(:invoice_payload) => String.t(),
    required(:shipping_option_id) => String.t(),
    optional(:order_info) => order_info(),
    required(:telegram_payment_charge_id) => String.t(),
    required(:provider_payment_charge_id) => String.t()
  }

  @type order_info :: %{
    optional(:name) => String.t(),
    optional(:phone_number) => String.t(),
    optional(:email) => String.t(),
    optional(:shipping_address) => shipping_address()
  }

  @type shipping_address :: %{
    required(:country_code) => String.t(),
    required(:state) => String.t(),
    required(:city) => String.t(),
    required(:street_line1) => String.t(),
    required(:street_line2) => String.t(),
    required(:post_code) => String.t()
  }

  @type passport_data :: %{
    required(:data) => [encrypted_passport_element()],
    required(:credentials) => encrypted_credentials()
  }

  @type encrypted_passport_element :: %{
    required(:type) => String.t(),
    optional(:data) => String.t(),
    optional(:phone_number) => String.t(),
    optional(:email) => String.t(),
    optional(:files) => [passport_file()],
    optional(:front_side) => passport_file(),
    optional(:reverse_side) => passport_file(),
    optional(:selfie) => passport_file(),
    optional(:translation) => [passport_file()],
    optional(:hash) => String.t()
  }

  @type passport_file :: %{
    required(:file_id) => String.t(),
    required(:file_unique_id) => String.t(),
    required(:file_size) => integer,
    required(:file_date) => integer
  }

  @type encrypted_credentials :: %{
    required(:data) => String.t(),
    required(:hash) => String.t(),
    required(:secret) => String.t()
  }

  @type sticker :: %{
    required(:file_id) => String.t(),
    required(:file_unique_id) => String.t(),
    required(:width) => integer,
    required(:height) => integer,
    required(:is_animated) => boolean,
    required(:is_video) => boolean,
    optional(:thumbnail) => photo_size(),
    optional(:emoji) => String.t(),
    optional(:set_name) => String.t(),
    optional(:mask_position) => mask_position(),
    optional(:file_size) => integer
  }

  @type mask_position :: %{
    required(:point) => String.t(),
    required(:scale) => float,
    optional(:x_shift) => float,
    optional(:y_shift) => float
  }

  # --------------------------------------------------------------------------
  # Update Types
  # --------------------------------------------------------------------------

  @type update :: %{
    required(:update_id) => integer,
    optional(:message) => message(),
    optional(:edited_message) => message(),
    optional(:channel_post) => message(),
    optional(:edited_channel_post) => message(),
    optional(:inline_query) => inline_query(),
    optional(:chosen_inline_result) => chosen_inline_result(),
    optional(:callback_query) => callback_query(),
    optional(:shipping_query) => shipping_query(),
    optional(:pre_checkout_query) => pre_checkout_query(),
    optional(:poll) => poll(),
    optional(:poll_answer) => poll_answer()
  }

  @type inline_query :: %{
    required(:id) => String.t(),
    required(:from) => user(),
    required(:query) => String.t(),
    required(:offset) => String.t(),
    optional(:chat_type) => String.t(),
    optional(:location) => location()
  }

  @type chosen_inline_result :: %{
    required(:result_id) => String.t(),
    required(:from) => user(),
    required(:query) => String.t(),
    optional(:location) => location(),
    optional(:inline_message_id) => String.t()
  }

  @type callback_query :: %{
    required(:id) => String.t(),
    required(:from) => user(),
    optional(:message) => message(),
    optional(:inline_message_id) => String.t(),
    optional(:chat_instance) => String.t(),
    optional(:chat) => chat(),
    optional(:date) => integer,
    optional(:game_short_name) => String.t(),
    optional(:data) => String.t()
  }

  @type shipping_query :: %{
    required(:id) => String.t(),
    required(:from) => user(),
    required(:invoice_payload) => String.t(),
    required(:shipping_address) => shipping_address()
  }

  @type pre_checkout_query :: %{
    required(:id) => String.t(),
    required(:from) => user(),
    required(:currency) => String.t(),
    required(:total_amount) => integer,
    required(:invoice_payload) => String.t(),
    optional(:shipping_option_id) => String.t(),
    optional(:order_info) => order_info()
  }

  @type poll_answer :: %{
    required(:poll_id) => String.t(),
    required(:user) => user(),
    required(:option_ids) => [integer]
  }

  # --------------------------------------------------------------------------
  # Webhook Types
  # --------------------------------------------------------------------------

  @type webhook_info :: %{
    required(:url) => String.t(),
    required(:has_custom_certificate) => boolean,
    required(:pending_update_count) => integer,
    optional(:ip_address) => String.t(),
    optional(:last_error_date) => integer,
    optional(:last_error_message) => String.t(),
    optional(:max_connections) => integer,
    optional(:allowed_updates) => [String.t()]
  }

  # --------------------------------------------------------------------------
  # Input Types
  # --------------------------------------------------------------------------

  @type input_file :: %{
    required(:path) => String.t(),
    optional(:file_name) => String.t(),
    optional(:mime_type) => String.t()
  }

  @type inline_keyboard_button :: %{
    required(:text) => String.t(),
    optional(:url) => String.t(),
    optional(:callback_data) => String.t(),
    optional(:callback_game) => map(),
    optional(:switch_inline_query) => String.t(),
    optional(:switch_inline_query_current_chat) => String.t(),
    optional(:pay) => boolean
  }

  @type inline_keyboard_markup :: %{
    required(:inline_keyboard) => [[inline_keyboard_button()]]
  }

  @type reply_keyboard_markup :: %{
    required(:keyboard) => [[keyboard_button()]],
    optional(:resize_keyboard) => boolean,
    optional(:one_time_keyboard) => boolean,
    optional(:input_field_placeholder) => String.t(),
    optional(:selective) => boolean
  }

  @type keyboard_button :: %{
    required(:text) => String.t(),
    optional(:request_contact) => boolean,
    optional(:request_location) => boolean,
    optional(:request_poll) => keyboard_button_poll_type()
  }

  @type keyboard_button_poll_type :: %{
    optional(:type) => String.t()
  }

  @type force_reply :: %{
    required(:force_reply) => boolean,
    optional(:input_field_placeholder) => String.t(),
    optional(:selective) => boolean
  }
end
