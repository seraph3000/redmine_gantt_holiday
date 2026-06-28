# frozen_string_literal: true

# =====================================================================
# Redmine Gantt Holiday plugin
# 
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================

class GanttHolidayProjectsController < ApplicationController
  # Redmine標準のフィルターを使ってプロジェクトを特定＆権限チェック
  before_action :find_project_by_project_id
  before_action :authorize

  def update
    # 既存の設定があれば取得、なければ新規作成の準備
    ph = ProjectHoliday.find_or_initialize_by(project_id: @project.id)
    ph.holiday_cal_name = params[:holiday_cal_name]
    
    if ph.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = l(:error_save_failed)
    end
    
    # プロジェクト設定画面の「休日設定」タブへリダイレクト
    redirect_to settings_project_path(@project, tab: 'holiday')
  end
end