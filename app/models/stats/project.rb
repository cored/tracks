class Project
  SECONDS_PER_DAY = 86400;
  attr_reader :current_user, :today, :projects_and_actions, 
    :projects_and_actions_last30days, :projects_and_runtime_sql,
    :projects_and_runtime

  def initialize(current_user, today, cut_off_month = nil)
    @current_user = current_user
    @today = today
    @cut_off_month = cut_off_month
  end

  def compute
    # get the first 10 projects and their action count (all actions)
    #
    # Went from GROUP BY p.id to p.name for compatibility with postgresql. Since
    # the name is forced to be unique, this should work.
    @projects_and_actions = current_user.projects.find_by_sql(
      [sql, current_user.id]
    )

    # get the first 10 projects with their actions count of actions that have
    # been created or completed the past 30 days

    # using GROUP BY p.name (was: p.id) for compatibility with Postgresql. Since
    # you cannot create two contexts with the same name, this will work.
    @projects_and_actions_last30days = current_user.projects.find_by_sql(
      [sql(@cut_off_month), current_user.id, @cut_off_month, @cut_off_month]
    )

    # get the first 10 projects and their running time (creation date versus
    # now())
    @projects_and_runtime_sql = current_user.projects.find_by_sql(
      sql_projects_and_runtime(current_user)
    )

    i=0
    @projects_and_runtime = Array.new(10, [-1, t('common.not_available_abbr'), t('common.not_available_abbr')])
    @projects_and_runtime_sql.each do |r|
      days = difference_in_days(@today, r.created_at)
      # add one so that a project that you just created returns 1 day
      @projects_and_runtime[i]=[r.id, r.name, days.to_i+1]
      i += 1
    end
  end

  private 

  def difference_in_days(date1, date2)
    return ((date1.utc.at_midnight-date2.utc.at_midnight)/SECONDS_PER_DAY).to_i
  end

  def sql(cut_off_month = nil)
    query = "SELECT p.id, p.name, count(*) AS count "
    query << "FROM projects p, todos t "
    query <<  "WHERE p.id = t.project_id "
    if cut_off_month
      query <<  "AND (t.created_at > ? OR t.completed_at > ?) "
    end
    query <<  "AND t.user_id=? "
    query <<  "GROUP BY p.id, p.name "
    query <<  "ORDER BY count DESC " 
    query <<  "LIMIT 10"
  end

  def sql_projects_and_runtime(current_user)
    "SELECT id, name, created_at "+
      "FROM projects "+
      "WHERE state='active' "+
      "AND user_id=#{current_user.id} "+
    "ORDER BY created_at ASC "+
      "LIMIT 10"
  end
end
