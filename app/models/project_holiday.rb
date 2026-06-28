# frozen_string_literal: true
# =====================================================================
# Redmine Gantt Holiday plugin
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================

class ProjectHoliday < ActiveRecord::Base
  self.table_name = 'gantt_project_holidays'

  belongs_to :project
  validate :holiday_cal_name_must_be_valid

  private
  def holiday_cal_name_must_be_valid
    return if holiday_cal_name.blank?
    return if GanttHolidaySelect.exists?(name: holiday_cal_name)
    errors.add(:holiday_cal_name, :invalid)
  end
end