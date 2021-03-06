# -*- encoding: utf-8 -*-
class BookmarksController < ApplicationController
  before_filter :store_location
  load_and_authorize_resource :except => :index
  authorize_resource :only => :index
  before_filter :get_user, :only => :index
  after_filter :solr_commit, :only => [:create, :update, :destroy]
  cache_sweeper :bookmark_sweeper, :only => [:create, :update, :destroy]

  # GET /bookmarks
  # GET /bookmarks.json
  def index
    search = Bookmark.search(:include => [:manifestation])
    query = params[:query].to_s.strip
    unless query.blank?
      @query = query.dup
    end
    user = @user
    unless current_user.has_role?('Librarian')
      if user and user != current_user and !user.try(:share_bookmarks)
        access_denied; return
      end
      if current_user == @user
        redirect_to bookmarks_url
        return
      end
    end

    search.build do
      fulltext query
      order_by(:created_at, :desc)
      if user
        with(:user_id).equal_to user.id
      else
        with(:user_id).equal_to current_user.id
      end
    end
    page = params[:page] || "1"
    flash[:page] = page if page.to_i >= 1
    search.query.paginate(page.to_i, Bookmark.default_per_page)
    @bookmarks = search.execute!.results

    respond_to do |format|
      format.html # index.html.erb
      format.json { render :json => @bookmarks }
    end
  end

  # GET /bookmarks/1
  # GET /bookmarks/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @bookmark }
    end
  end

  # GET /bookmarks/new
  def new
    @bookmark = current_user.bookmarks.new(params[:bookmark])
    manifestation = @bookmark.get_manifestation
    if manifestation
      if manifestation.bookmarked?(current_user)
        flash[:notice] = t('bookmark.already_bookmarked')
        redirect_to manifestation
        return
      end
      @bookmark.title = manifestation.original_title
    else
      @bookmark.title = Bookmark.get_title_from_url(@bookmark.url) unless @bookmark.title?
    end
  end

  # GET /bookmarks/1/edit
  def edit
  end

  # POST /bookmarks
  # POST /bookmarks.json
  def create
    @bookmark = current_user.bookmarks.new(params[:bookmark])

    respond_to do |format|
      if @bookmark.save
        flash[:notice] = t('controller.successfully_created', :model => t('activerecord.models.bookmark'))
        @bookmark.create_tag_index
        @bookmark.manifestation.index!
        if params[:mode] == 'tag_edit'
          format.html { redirect_to(@bookmark.manifestation) }
          format.json { render :json => @bookmark, :status => :created, :location => @bookmark }
        else
          format.html { redirect_to(@bookmark) }
          format.json { render :json => @bookmark, :status => :created, :location => @bookmark }
        end
      else
        @user = current_user
        format.html { render :action => "new" }
        format.json { render :json => @bookmark.errors, :status => :unprocessable_entity }
      end
    end

    session[:params][:bookmark] = nil if session[:params]
  end

  # PUT /bookmarks/1
  # PUT /bookmarks/1.json
  def update
    unless @bookmark.url.try(:bookmarkable?)
      access_denied; return
    end
    @bookmark.title = @bookmark.manifestation.try(:original_title)
    @bookmark.taggings.where(:tagger_id => @bookmark.user.id).map{|t| t.destroy}

    respond_to do |format|
      if @bookmark.update_attributes(params[:bookmark])
        flash[:notice] = t('controller.successfully_updated', :model => t('activerecord.models.bookmark'))
        @bookmark.manifestation.index!
        @bookmark.create_tag_index
        case params[:mode]
        when 'tag_edit'
          format.html { redirect_to @bookmark.manifestation }
          format.json { head :no_content }
        else
          format.html { redirect_to @bookmark }
          format.json { head :no_content }
        end
      else
        format.html { render :action => "edit" }
        format.json { render :json => @bookmark.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /bookmarks/1
  # DELETE /bookmarks/1.json
  def destroy
    @bookmark.destroy
    flash[:notice] = t('controller.successfully_deleted', :model => t('activerecord.models.bookmark'))
    @bookmark.create_tag_index

    if @user
      respond_to do |format|
        format.html { redirect_to user_bookmarks_url(@user) }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to user_bookmarks_url(@bookmark.user) }
        format.json { head :no_content }
      end
    end
  end
end
