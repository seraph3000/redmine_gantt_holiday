# frozen_string_literal: true

# =====================================================================
# Redmine Gantt Holiday plugin
# 
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================

module GanttHolidayProjectsHelperPatch
  def project_settings_tabs
    tabs = super
    # init.rbで定義した :manage_holiday 権限を持つ場合のみタブを追加
    if User.current.allowed_to?(:manage_holiday, @project)
      tabs << {
        name: 'holiday',
        action: :manage_holiday, # 権限名と一致させることで表示される
        partial: 'projects/settings/holiday',
        label: :label_holiday_settings # ja.yml の定義を使用
      }
    end
    tabs
  end
end