class ModalOpenLogsController < ApplicationController
  include Logging

  layout false

  def create
    create_modal_open_log(params[:via])
    render nothing: true, status: 200
  rescue => e
    logger.warn "#{self.class}##{__method__}: #{e.class} #{e.message}"
    render nothing: true, status: 500
  end
end
