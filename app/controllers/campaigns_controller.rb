class CampaignsController < ApplicationController
  def index
    @campaigns = Campaign.all
  end

  def show
    @campaign = Campaign.find(params[:id])
    @entities = BaseEntity.all
  end

  def new
    @campaign = Campaign.new
    @overlays = Overlay.all.group_by(&:overlay_type)
  end

  def create
    @campaign = Campaign.new(campaign_params)

    if @campaign.save
      redirect_to @campaign, notice: "Campaign created successfully"
    else
      @overlays = Overlay.all.group_by(&:overlay_type)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def campaign_params
    params.require(:campaign).permit(:name, active_overlays: [])
  end
end
