# frozen_string_literal: true

# =====================================================================
# Redmine Gantt Holiday plugin
# 
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================

class HolidaySelect < Enumeration
  has_many :holiday_values, foreign_key: 'calendar_id', dependent: :destroy
  OptionName = :enumeration_project_holiday
  after_create :copy_from_standard_calendar

  def option_name; OptionName; end
  def objects_count; 0; end
  def transfer_relations(to); end

  private

  def copy_from_standard_calendar
    return if self.name == '標準' || self.name == 'Standard'
    standard = HolidaySelect.find_by(name: ['標準', 'Standard'])
    return unless standard


    holidays_to_copy = standard.holiday_values.where(is_official: true).map do |sv|
      {
        calendar_id: self.id,
        holiday: sv.holiday,
        holiday_name: sv.holiday_name,
        active: sv.active,
        is_official: true,
      }
    end

    HolidayValue.insert_all(holidays_to_copy) if holidays_to_copy.any?
  end
end