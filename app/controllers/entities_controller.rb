class EntitiesController < ApplicationController
  def show
    @entity = BaseEntity.find_by!(entity_id: params[:entity_id])
  rescue ActiveRecord::RecordNotFound
    render plain: "Entity not found", status: :not_found
  end
end
