# frozen_string_literal: true

# =====================================================================
# Redmine Gantt Holiday plugin
# 
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================

Redmine::Plugin.register :redmine_gantt_holiday do
  name 'Redmine Gantt Holiday plugin'
  author 'Seraph3000'
  description 'Gantt chart holiday settings and sticky header.'
  version '2.0.16'
  url 'https://github.com/seraph3000/redmine_gantt_holiday'
  author_url 'https://github.com/seraph3000'

  menu  :admin_menu,
        :gantt_holiday_settings,
        { controller: 'gantt_holiday_settings', action: 'index' },
        caption: :label_holiday_settings,
        html: { class: 'icon icon-settings' },
        if: proc { User.current.admin? }

  project_module :gantt_holiday do
    permission :manage_holiday, { gantt_holiday_projects: [:update] }, require: :member
    permission :oyakodon_child_issue, { oyakodon: [:bulk_assign, :release] }, require: :member
  end
  Redmine::AccessControl.map do |map|
    map.permission :manage_gantt_holiday, { gantt_holiday_settings: [:index, :update, :import_csv] }, require: :admin
  end
end

require_relative 'lib/gantt_holiday_hooks'
require_relative 'lib/gantt_holiday_gantt_patch'
require_relative 'lib/gantt_holiday_projects_helper_patch'
require_relative 'lib/oyakodon_hooks'

unless Redmine::Helpers::Gantt.included_modules.include?(GanttHolidayGanttPatch)
  Redmine::Helpers::Gantt.prepend(GanttHolidayGanttPatch)
end
unless ProjectsHelper.included_modules.include?(GanttHolidayProjectsHelperPatch)
  ProjectsHelper.prepend(GanttHolidayProjectsHelperPatch)
end