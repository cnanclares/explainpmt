=begin License
  eXPlain Project Management Tool
  Copyright (C) 2005  John Wilger <johnwilger@gmail.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
=end LICENSE

class MilestonesController < ApplicationController
  before_filter :require_current_project, :except => [:milestones_calendar]
  popups :new, :create, :show, :edit, :update
  
  # Lists the milestones for the project.
  def index
    @page_title = "Milestones"
    if @params['show_all'] == '1'
      @past_milestones = 'all_past'
      @past_link_opts = [ 'show only recent', { :controller => 'milestones',
                                                :action => 'index',
                                                :project_id => @project.id } ]
      @past_title = "All Past Milestones"
    else
      @past_milestones = 'recent'
      @past_link_opts = [ 'show all', { :controller => 'milestones',
                                        :action => 'index', 
                                        :project_id => @project.id,
                                        :show_all => '1' } ]
      @past_title = "Recent Milestones"
    end
  end

  # Displays the form to add a new milestone.
  def new
    if @milestone = @session[:new_milestone]
      @session[:new_milestone] = nil
    else
      @milestone = Milestone.new
    end
    @page_title = "New Milestone"
  end

  # Creates a new milestone based on the information submitted from the #new
  # action.
  def create
    milestone = Milestone.new(@params['milestone'])
    milestone.project = @project
    if milestone.valid?
      milestone.save
      flash[:status] = "New milestone *#{milestone.name}* on " +
                        "*#{milestone.date}* was created."
      render 'layouts/refresh_parent_close_popup'
    else
      @session[:new_milestone] = milestone
      redirect_to :controller => 'milestones', :action => 'new',
                  :project_id => @project.id
    end
  end

  # Displays the form to edit milestone information. The milestone to edit is
  # identified by the 'id' request parameter.
  def edit
    if @milestone = @session[:edit_milestone]
      @session[:edit_milestone] = nil
    else
      @milestone = Milestone.find(@params['id'])
    end
  end

  # Updates the milestone identified by the 'id' request parameter with the
  # information submitted from the #edit action.
  def update
    milestone = Milestone.find(@params['id'])
    milestone.attributes = @params['milestone']
    if milestone.valid?
      milestone.save
      flash[:status] = "Changes to milestone \"#{milestone.name}\" have " +
                        "been saved."
      render 'layouts/refresh_parent_close_popup'
    else
      @session[:edit_milestone] = milestone
      redirect_to :controller => 'milestones', :action => 'edit',
                  :id => milestone.id,
                  :project_id => milestone.project.id
    end
  end

  # Deletes the milestone identified by the 'id' request parameter.
  def delete
    milestone = Milestone.find(@params['id'])
    milestone.destroy
    flash[:status] = "Milestone *#{milestone.name}* on *#{milestone.date}*" +
                      " has been deleted."
    redirect_to :controller => 'milestones', :action => 'index',
                :project_id => @project.id
  end

  # Displays the details for the milestone identified by the 'id' request
  # parameter.
  def show
    @milestone = Milestone.find(@params['id'])
  end

  # Renders the partial template for the milestones calendar component.
  def milestones_calendar
    @calendar_title = 'Upcoming Milestones:'
    if @project
      milestones = @project.milestones
    else
      milestones = @session[:current_user].projects.collect{|p| p.milestones}
      @calendar_title.gsub!(':', ' (all projects):')
    end
    milestones = milestones.flatten.select { |m|
      m.date >= Date.today && m.date < Date.today + 14
    }
    days = []
    14.times do |i|
      current_day = Date.today + i
      days << {
        :date => current_day,
        :name => Date::DAYNAMES[current_day.wday],
        :milestones => milestones.select { |m| m.date == current_day }
      }
    end
    @days = days
    render_partial 'milestones_calendar'
  end
  
  # Renders the partial template for the list component. Requires the parameter
  # 'include' to be set to one of 'future', 'recent', or 'all_past'
  def list
    case @params['include']
    when 'future'
      @milestones = @project.future_milestones
    when 'recent'
      @milestones = @project.recent_milestones
    when 'all_past'
      @milestones = @project.past_milestones
    else
      @milestones = []
    end
    unless @milestones.empty?
      render_partial 'list'
    else
      render_text '<p>Nothing to show.</p>'
    end
  end
end
