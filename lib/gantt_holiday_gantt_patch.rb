# frozen_string_literal: true

# =====================================================================
# Redmine Gantt Holiday plugin
# 
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================

module GanttHolidayGanttPatch
  attr_accessor :draw_relations, :draw_progress_line, :set_filter, :query

  def initialize(options={})
    super

    if User.current.logged?
      pref = User.current.preference # .pref だとメソッド干渉の恐れがあるため確実に取得

      # ★ クリアボタン検知（set_filter=1 かつ query パラメータなし）
      query_params = options[:query] || options['query']
      set_filter_val = options[:set_filter] || options['set_filter']
      if set_filter_val.to_i == 1 && query_params.nil?
        pref[:gantt_month_from] = nil
        pref[:gantt_year_from] = nil
        pref[:gantt_column_names] = nil
        pref[:gantt_draw_selected_columns] = nil
        pref[:gantt_progress_line] = nil
        pref[:gantt_relations] = nil
        pref.save
      end

      # 1. ズーム倍率と表示月数
      @zoom = (options[:zoom] || options['zoom'] || pref[:gantt_zoom] || @zoom).to_i
      @months = (options[:months] || options['months'] || pref[:gantt_months] || @months).to_i
      if options[:zoom].present? || options['zoom'].present? || options[:months].present? || options['months'].present?
        pref[:gantt_zoom] = @zoom
        pref[:gantt_months] = @months
        pref.save
      end

      # 2. 開始年・月
      @set_filter = options[:set_filter] || options['set_filter']
      year_opt = options[:year] || options['year']
      month_opt = options[:month] || options['month']

      if year_opt && year_opt.to_i > 0
        @year_from = year_opt.to_i
        @month_from = (month_opt && month_opt.to_i >= 1 && month_opt.to_i <= 12) ? month_opt.to_i : 1
      elsif @set_filter.to_i == 1
        @month_from = User.current.today.month
        @year_from = User.current.today.year
      else
        @month_from = pref[:gantt_month_from] || User.current.today.month
        @year_from = pref[:gantt_year_from] || User.current.today.year
      end

      if @month_from != pref[:gantt_month_from] || @year_from != pref[:gantt_year_from]
        pref[:gantt_month_from] = @month_from
        pref[:gantt_year_from] = @year_from
        pref.save
      end

      # ========================================
      # 3. 記憶の書き込み
      # ========================================
      query_params = options[:query] || options['query']
      
      if query_params
        # 関連線
        raw_rel = query_params[:draw_relations] || query_params['draw_relations']
        raw_rel = raw_rel.last if raw_rel.is_a?(Array)
        if !raw_rel.nil? && raw_rel.to_s != pref[:gantt_relations].to_s
          pref[:gantt_relations] = raw_rel.to_s
          pref.save
        end

        # イナズマ線
        raw_prg = query_params[:draw_progress_line] || query_params['draw_progress_line']
        raw_prg = raw_prg.last if raw_prg.is_a?(Array)
        if !raw_prg.nil? && raw_prg.to_s != pref[:gantt_progress_line].to_s
          pref[:gantt_progress_line] = raw_prg.to_s
          pref.save
        end

        # カラム表示ON/OFF
        raw_cols_flag = query_params[:draw_selected_columns] || query_params['draw_selected_columns']
        raw_cols_flag = raw_cols_flag.last if raw_cols_flag.is_a?(Array)
        if !raw_cols_flag.nil? && raw_cols_flag.to_s != pref[:gantt_draw_selected_columns].to_s
          pref[:gantt_draw_selected_columns] = raw_cols_flag.to_s
          pref.save
        end
      end

      # カラム内容（params[:c] はトップレベル）
      raw_col_names = options[:c] || options['c']
      if raw_col_names.present?
        names = Array(raw_col_names).map(&:to_s).reject(&:blank?)
        if names != Array(pref[:gantt_column_names])
          pref[:gantt_column_names] = names
          pref.save
        end
      end
      # 4. 期間の再計算
      @date_from = Date.civil(@year_from, @month_from, 1)
      @date_to = (@date_from >> @months) - 1
    end

  end

  # ========================================
  # 記憶の呼び出し＆UIへの強制反映
  # コントローラーが無視しようと、ビューが描画される直前に
  # @query の中身を俺たちのDBの記憶で強制的に書き換える！
  # ========================================
  def query=(q)
    ## デバッグ
    super(q)
    if q && User.current.logged?
      pref = User.current.preference
      
      if pref[:gantt_relations].present?
        q.draw_relations = pref[:gantt_relations].to_s
      end
      
      if pref[:gantt_progress_line].present?
        q.draw_progress_line = pref[:gantt_progress_line].to_s
      end

      if pref[:gantt_draw_selected_columns].present?
        q.draw_selected_columns = pref[:gantt_draw_selected_columns].to_s
      end

      if pref[:gantt_column_names].present?
        q.column_names = Array(pref[:gantt_column_names]).map(&:to_sym)
      end
    end
  end

  def holiday_dates
    return [] unless project

    # 1. プロジェクト設定画面で選んだカレンダー名（会社Aなど）を取得
    #    設定がない場合は '標準' or 'Standard' をデフォルトにする
    default_cal_name = GanttHolidaySelect.find_by(name: ['標準', 'Standard'])&.name || '標準'
    cal_name = ProjectHoliday.find_by(project_id: project.id)&.holiday_cal_name || default_cal_name

    # 2. そのカレンダー名に紐づく GanttHolidaySelect の ID を取得
    #    ※ '標準' などの名前からIDを引く
    calendar_record = GanttHolidaySelect.find_by(name: cal_name)

    # 該当するカレンダーが見つからなければ、念のため「標準」でフォールバック
    calendar_record ||= GanttHolidaySelect.find_by(name: default_cal_name)

    return [] unless calendar_record

    # 3. そのカレンダーIDに紐づく有効な休日データを配列にして返す
    ##HolidayValue.where(calendar_id: calendar_record.id, active: true).pluck(:holiday).map(&:to_s)
    HolidayValue.where(calendar_id: calendar_record.id).map do |hv|
      { date: hv.holiday.to_s, active: hv.active }
    end
  end
end