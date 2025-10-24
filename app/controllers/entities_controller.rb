class EntitiesController < ApplicationController
  def show
    @campaign = Campaign.find(params[:campaign_id])
    @resolved_data = EntityResolver.resolve(
      entity_id: params[:entity_id],
      campaign: @campaign
    )

    if @resolved_data.nil?
      render plain: "Entity not found", status: :not_found
      return
    end
  rescue ActiveRecord::RecordNotFound
    render plain: "Campaign not found", status: :not_found
  end
end
