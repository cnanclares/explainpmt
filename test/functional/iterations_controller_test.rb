require File.dirname(__FILE__)  + '/../test_helper'
require 'iterations_controller'

# Re-raise errors caught by the controller.
class IterationsController; def rescue_action(e) raise e end; end

class IterationsControllerTest < Test::Unit::TestCase
  fixtures ALL_FIXTURES

  def setup
    @controller = IterationsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @request.session[ :current_user ] = User.find 1

    @project_one = Project.find 1
    @iteration_one = Iteration.find 1
    @iteration_two = Iteration.find 2
  end

  def test_index_no_project_id
    get :index
    assert_redirected_to :controller => 'error', :action => 'index'
    assert_equal "You attempted to access a view that requires a project to " +
      "be selected, but no project id was set in your request.",
      flash[ :error ]
  end

  def test_index
    past = Iteration.find 7
    current = Iteration.find 8
    future = Iteration.find 9
    
    get :index, 'project_id' => 3
    assert_redirected_to :controller => 'iterations', :action => 'show',
      :id => '8', :project_id => '3'
    
    current.destroy
    get :index, 'project_id' => 3
    assert_redirected_to :controller => 'iterations', :action => 'show',
      :id => '7', :project_id => '3'
    
    past.destroy
    get :index, 'project_id' => 3
    assert_redirected_to :controller => 'iterations', :action => 'show',
      :id => '9', :project_id => '3'
    
    future.destroy
    get :index, 'project_id' => 3
    assert_response :success
    assert_template 'index'
  end

  def test_show
    get :show, 'id' => 1, 'project_id' => 1
    assert_response :success
    assert_template 'show'
    assert_equal @iteration_one, assigns( :iteration )
    assert assigns( :stories )
  end

  def test_new
    get :new, 'project_id' => 1
    assert_response :success
    assert_template 'new'
    assert assigns( :object ).class == Iteration
    assert assigns( :object ).new_record?
  end

  def test_create
    Iteration.destroy_all
    post :create, 'project_id' => @project_one.id,
      'object' => {
        'start_date(1i)' => Date.today.year.to_s,
        'start_date(2i)' => Date.today.mon.to_s,
        'start_date(3i)' => Date.today.day.to_s,
        'length' => '14',
        'budget' => '120',
        'name' => 'test'
      }
    assert_equal 1, Iteration.count
    assert_response :success
    assert_template 'layouts/refresh_parent_close_popup'
  end

  def test_delete
    get :delete, 'id' => 1, 'project_id' => 1
    assert_redirected_to :controller => 'iterations', :action => 'index',
      :project_id => '1'
    assert_raise( ActiveRecord::RecordNotFound ) do
      Iteration.find 1
    end
    assert_equal [], 
      Story.find( :all, :conditions => [ 'iteration_id = ?', 1 ] )
  end

  def test_edit
    get :edit, 'id' => 1, 'project_id' => 1
    assert_response :success
    assert_template 'edit'
    assert_equal @iteration_one, assigns( :object )
  end

  def test_update
    post :update, 'id' => 1, 'project_id' => 1,
      'iteration' => { 'length' => '10' }
    assert Iteration.find(1).length = '10'
    assert_response :success
    assert_template 'layouts/refresh_parent_close_popup'
  end

  def test_move_stories_to_backlog
    post :move_stories, 'id' => 1, 'project_id' => 1,
      'selected_stories' => [ 4, 5 ], 'move_to' => 0
    assert_redirected_to :controller => 'iterations', :action => 'show',
      :id => '1', :project_id => '1'
    sc_one = Story.find 4
    assert_nil sc_one.iteration
    assert_nil sc_one.owner
    sc_two = Story.find 5
    assert_nil sc_two.iteration
    assert_nil sc_two.owner
    assert flash[ :status ]
  end

  def test_move_stories_to_another_iteration
    post :move_stories, 'id' => 1, 'project_id' => 1,
      'selected_stories' => [ 4, 5 ], 'move_to' => 2
    assert_redirected_to :controller => 'iterations', :action => 'show',
      :id => '1', :project_id => '1'
    sc_one = Story.find 4
    assert_equal @iteration_two, sc_one.iteration
    sc_two = Story.find 5
    assert_equal @iteration_two, sc_two.iteration
    assert flash[ :status ]
  end

  def test_move_stories_raises_no_error_if_no_stories_selected
    assert_nothing_raised do
      post :move_stories, :project_id => 1, :move_to => 2
    end
  end

  def test_select_stories
    get :select_stories, 'id' => 1, 'project_id' => 1
    assert_response :success
    assert_template 'select_stories'
    assert_equal @iteration_one, assigns( :iteration )
    assigns( :stories ).each do |s|
      assert_nil s.iteration
      assert s.status != Story::Status::New
      assert s.status != Story::Status::Cancelled
    end
  end

  def test_assign_stories
    post :assign_stories, :id => 1, :project_id => 1,
      :selected_stories => [ 4, 5 ], :move_to => 2
    assert_response :success
    assert_template 'layouts/refresh_parent_close_popup'
    sc_one = Story.find 4
    assert_equal @iteration_two, sc_one.iteration
    sc_two = Story.find 5
    assert_equal @iteration_two, sc_two.iteration
    assert flash[ :status ]
  end

  def test_assign_stories_not_defined
    story = @project_one.stories.create 'title' => 'undefed story'
    post :move_stories, 'project_id' => 1,
      'selected_stories' => [story.id], 'move_to' => 1 
    assert_redirected_to :controller => 'stories', :action => 'index',
      :project_id => '1'
    assert_nil flash[ :status ]
    assert flash[ :error ]
  end
end