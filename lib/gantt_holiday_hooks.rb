# frozen_string_literal: true

# =====================================================================
# Redmine Gantt Holiday plugin
# 
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================

class GanttHolidayHooks < Redmine::Hook::ViewListener
  def view_layouts_base_html_head(context = {})
    controller = context[:controller]
    return '' unless controller&.controller_name == 'gantts'

    gantt = controller.instance_variable_get(:@gantt)
    return '' unless gantt

    holiday_json = ERB::Util.json_escape(gantt.holiday_dates.to_json)
    start_date   = ERB::Util.json_escape(gantt.date_from.to_s)
    
    # controllerのview_context経由でnonce対応のjavascript_tagを呼ぶ
    view = controller.view_context
    inline_js = view.javascript_tag(
      "var gantt_holidays = #{holiday_json}; var gantt_start_date = '#{start_date}';",
      nonce: true
    )

    tags = [
      stylesheet_link_tag('gantt_holiday', plugin: 'redmine_gantt_holiday'),
      inline_js,
      javascript_include_tag('gantt_holiday_patch', plugin: 'redmine_gantt_holiday')
    ]
    tags.join("\n").html_safe
  end
end