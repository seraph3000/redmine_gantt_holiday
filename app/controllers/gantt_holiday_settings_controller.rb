# frozen_string_literal: true

# =====================================================================
# Redmine Gantt Holiday plugin
# 
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================

require 'csv'

class GanttHolidaySettingsController < ApplicationController
  layout 'admin'
  menu_item :gantt_holiday_settings
  before_action :require_admin

  def index
    @calendars = GanttHolidaySelect.where(active: true).order(:position)
    @selected_calendar_id = params[:calendar_id].presence || @calendars.first&.id
    @selected_year = (params[:year] || Date.current.year).to_i

    if @selected_calendar_id
      # 対象年の「1月1日」と「12月31日」の範囲を作る
      start_date = Date.civil(@selected_year, 1, 1)
      end_date   = Date.civil(@selected_year, 12, 31)

      @holidays = HolidayValue.where(calendar_id: @selected_calendar_id)
                              .where(holiday: start_date..end_date)
                              .order(:holiday)
    else
      @holidays = []
    end
  end

  def update
    calendar_id = params[:calendar_id]
    unless GanttHolidaySelect.exists?(id: calendar_id)
      flash[:error] = l(:error_invalid_calendar)
      return redirect_to action: 'index'
    end
    year = params[:year]

    # 1. 既存休日の更新・削除ロジック
    if params[:holidays].present?
      params[:holidays].each do |id, checked|
        record = HolidayValue.where(calendar_id: calendar_id).find_by(id: id)
        next unless record

        # 送信値の型ブレを防ぐため .to_s で厳密に '0' か判定
        if checked.to_s == '0'
          # チェックが外された場合
          if record.has_attribute?(:is_official) && record.is_official
            # 公式祝日の場合：モデルのバリデーションを無視して強制的に「論理削除(active: false)」
            record.update_columns(active: false)
          else
            # 手動追加（非公式）の場合：物理削除
            record.destroy
          end
        else
          # チェックが入っている場合：強制的に「有効(active: true)」
          record.update_columns(active: true)
        end
      end
    end

    # 2. 新規追加（および既存指定での上書き）行の保存ロジック
    if params[:new_holidays].present?
        params[:new_holidays].values.each do |new_h|
        if new_h[:date].present? && new_h[:check].to_s == '1'
          begin
            parsed_date = Date.parse(new_h[:date])

            # find_or_initialize_by に変更: 既存があれば取得、なければ新規準備
            hv = HolidayValue.find_or_initialize_by(calendar_id: calendar_id, holiday: parsed_date)

            # 既存レコードであっても、入力された名前で容赦なく上書きする
            hv.holiday_name = new_h[:name].presence || ""
            hv.active = true

            # 新規作成の時のみ「非公式(手動)」フラグを立てる
            # (もし標準の祝日名を上書きした場合は、公式フラグを維持してあげる親切設計)
            hv.is_official = false if hv.new_record?

            hv.save!
          rescue ArgumentError
            next
          end
        end
      end
    end

    flash[:notice] = l(:notice_successful_update)
    redirect_to action: 'index', calendar_id: calendar_id, year: year
  end

  def import_csv
    calendar_id = params[:calendar_id]
    unless GanttHolidaySelect.exists?(id: calendar_id)
      flash[:error] = l(:error_invalid_calendar)
      return redirect_to action: 'index'
    end
    year = params[:year]
    file = params[:csv_file]

    if file.present?
      if file.size > 1.megabytes
        flash[:error] = l(:error_file_too_large_1mb)
        return redirect_to action: 'index', calendar_id: calendar_id, year: year
      end

      begin
        raw_data = file.read

        # 文字コードの判定と変換 (内閣府CSVはShift_JISの可能性が高い)
        if raw_data.force_encoding('UTF-8').valid_encoding?
          # UTF-8の場合はBOM(バイトオーダーマーク)が付いていれば除去する
          csv_data = raw_data.sub("\xEF\xBB\xBF", '')
        else
          # UTF-8として不正ならShift_JISと見なしてUTF-8に変換
          csv_data = raw_data.force_encoding('Shift_JIS').encode('UTF-8', invalid: :replace, undef: :replace)
        end

        HolidayValue.transaction do
          CSV.parse(csv_data, headers: false) do |row|
            date_str = row[0]
            name_str = row[1].to_s.strip
            next if date_str.blank?

            begin
              parsed_date = Date.parse(date_str)

              # 既存のレコードがあれば更新、なければ新規作成
              hv = HolidayValue.find_or_initialize_by(calendar_id: calendar_id, holiday: parsed_date)
              hv.holiday_name = name_str
              hv.active = true
              hv.is_official = true # 「公式祝日」としてマーク
              hv.save!
            rescue ArgumentError
              # 日付としてパースできない行(1行目のヘッダーなど)は華麗にスルー
              next
            end
          end
        end
        flash[:notice] = l(:notice_csv_import_success)
      rescue => e
        Rails.logger.error("[gantt_holiday] CSV import failed: #{e.full_message}")
        flash[:error] = l(:error_csv_import_failed_generic)
      end
    else
      flash[:error] = l(:error_file_not_selected)
    end
    
    redirect_to action: 'index', calendar_id: calendar_id, year: year
  end
end