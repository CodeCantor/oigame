# encoding: utf-8
class CampaignsController < ApplicationController

  protect_from_forgery :except => :message 
  layout 'application', :except => [:widget, :widget_iframe]
  before_filter :authenticate_user!, :only => [:new, :edit, :create, :update, :destroy, :moderated, :activate]

  # GET /campaigns
  # GET /campaigns.json
  def index
    @campaigns = Campaign.last_campaigns
    @tags = Campaign.published.tag_counts_on(:tags)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @campaigns }
    end
  end

  # GET /campaigns/1
  # GET /campaigns/1.json
  def show
    # Solo el admin puede ver campañas no moderadas
    if user_signed_in? && (current_user.is_admin || current_user.is_editor)
      @campaign = Campaign.find_by_slug(params[:id])
    else
      @campaign = Campaign.published.find_by_slug(params[:id])
    end

    unless @campaign
      render :file => "#{Rails.root}/public/404.html", :layout => false, :status => 404
      
      return
    end
    
    # @stats_data es: [fecha, mensajes enviados]
    @stats_data = '[["2011-09-23 4:00PM",3023], ["2011-09-24 4:00PM",6023],  ["2011-09-25 4:00PM",16023],  ["2011-09-26 4:00PM",26023],  ["2011-09-27 4:00PM",46023]]'

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @campaign }
    end
  end

  # GET /campaigns/new
  # GET /campaigns/new.json
  def new
    @campaign = Campaign.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @campaign }
    end
  end

  # GET /campaigns/1/edit
  def edit
    if current_user.is_editor || current_user.is_admin
      @campaign = Campaign.find_by_slug(params[:id])
    else
      @campaign = Campaign.published.find_by_slug(params[:id])
    end

    unless @campaign
      render :file => "#{Rails.root}/public/404.html", :layout => false, :status => 404

      return
    end

    unless @campaign.user == current_user || current_user.is_editor || current_user.is_admin
      flash[:error] = 'No estas autorizado a editar esta campaña'
      redirect_to @campaign

      return
    end
  end

  # POST /campaigns
  # POST /campaigns.json
  def create
    @campaign = Campaign.new(params[:campaign])
    @campaign.user = current_user

    respond_to do |format|
      if @campaign.save
        Mailman.send_campaign_to_social_council(@campaign).deliver
        format.html { redirect_to campaigns_url, notice: 'Tu campaña se ha creado con éxito y está pendiente de moderación.' }
        format.json { render json: @campaign, status: :created, location: @campaign }
      else
        format.html { render action: "new" }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /campaigns/1
  # PUT /campaigns/1.json
  def update
    if current_user.is_editor || current_user.is_admin
      @campaign = Campaign.find_by_slug(params[:id])
    else
      @campaign = Campaign.published.find_by_slug(params[:id])
    end
    
    unless @campaign
      render :file => "#{Rails.root}/public/404.html", :layout => false, :status => 404

      return
    end

    # Solo el usuario autorizado puede actualizar una campaña
    unless @campaign.user == current_user || current_user.is_editor || current_user.is_admin
      flash[:error] = 'No estas autorizado para editar esta campaña'
      redirect_to @campaign

      return
    end

    respond_to do |format|
      if @campaign.update_attributes(params[:campaign])
        format.html { redirect_to @campaign, notice: 'Campaign was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /campaigns/1
  # DELETE /campaigns/1.json
  def destroy
    if current_user.is_admin || current_user.is_editor
      @campaign = Campaign.find_by_slug(params[:id])
    else
      @campaign = Campaign.published.find_by_slug(params[:id])
    end
    
    unless @campaign
      render :file => "#{Rails.root}/public/404.html", :layout => false, :status => 404

      return
    end

    # Solo el usuario autorizado puede borrar una campaña
    unless @campaign.user == current_user || current_user.is_admin
      flash[:error] = 'No estas autorizado para borrar esta campaña'
      redirect_to @campaign

      return
    end

    @campaign.destroy

    respond_to do |format|
      format.html { redirect_to campaigns_url }
      format.json { head :ok }
    end
  end

  def widget
    @campaign = Campaign.published.find_by_slug(params[:id])
  end

  def widget_iframe
    @campaign = Campaign.published.find_by_slug(params[:id])
    render :partial => "widget_iframe"
  end

  def tag
    @campaigns = Campaign.last_campaigns_by_tag(params[:id])
    @tags = Campaign.published.tag_counts_on(:tags)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @campaigns }
    end
  end

  def message
    if request.post?
      to = user_signed_in? ? current_user.email : params[:email]
      campaign = Campaign.published.find_by_slug(params[:id])
      Mailman.send_message_to_user(to, params[:subject], params[:body], campaign).deliver
      redirect_to message_campaign_path, :notice => 'Gracias por unirte a esta campaña'

      return
    end
  end

  def moderated
    if current_user.is_admin
      @campaigns = Campaign.last_campaigns_moderated
      @tags = Campaign.published.tag_counts_on(:tags)
    else
      flash[:error] = "No tienes acceso a esta página"
      redirect_to campaigns_url

      return
    end
    
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @campaigns }
    end
  end

  def activate
    if current_user.is_admin
      @campaign = Campaign.find_by_slug(params[:id])
      @campaign.activate!
      redirect_to @campaign, :notice => 'La campaña se ha activado con éxito'

      return
    else
      flash[:error] = "No tienes acceso a esta página"
      redirect_to campaigns_url
    end
  end
end
