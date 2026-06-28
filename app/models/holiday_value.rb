# frozen_string_literal: true
# =====================================================================
# Redmine Gantt Holiday plugin
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================

class HolidayValue < ActiveRecord::Base
  self.table_name = 'gantt_holiday_values'

  belongs_to :holiday_select, foreign_key: 'calendar_id', class_name: 'GanttHolidaySelect'
  validates :calendar_id, presence: true
  validates :holiday, presence: true, uniqueness: { scope: :calendar_id }
end