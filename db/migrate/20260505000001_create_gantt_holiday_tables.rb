class CreateGanttHolidayTables < ActiveRecord::Migration[7.2]
  def up
    unless table_exists?(:gantt_holiday_values)
      create_table :gantt_holiday_values do |t|
        t.integer :calendar_id, null: false
        t.date :holiday, null: false
        t.string :holiday_name
        t.boolean :active, default: true, null: false
        t.boolean :is_official, default: false, null: false
      end
      add_index :gantt_holiday_values, :calendar_id
      add_index :gantt_holiday_values, [:calendar_id, :holiday], unique: true
    end

    unless table_exists?(:gantt_project_holidays)
      create_table :gantt_project_holidays do |t|
        t.integer :project_id, null: false
        t.string :holiday_cal_name, null: false
      end
      add_index :gantt_project_holidays, :project_id, unique: true
    end

    # システム言語で初期カレンダー名を切替（標準 / Standard）
    sys_lang = begin
                 Setting.default_language.to_s
               rescue
                 'en'
               end
    cal_name = (sys_lang == 'ja') ? '標準' : 'Standard'

    # type は新タイプ 'GanttHolidaySelect'。旧 'HolidaySelect' とは完全分離
    execute(ActiveRecord::Base.sanitize_sql_array([
      "INSERT INTO enumerations (name, position, is_default, type, active) " \
      "SELECT ?, 1, false, 'GanttHolidaySelect', true " \
      "WHERE NOT EXISTS (SELECT 1 FROM enumerations WHERE type = 'GanttHolidaySelect' AND name IN ('標準', 'Standard'))",
      cal_name
    ]))
  end

  def down
    # ★自分のtype（GanttHolidaySelect）だけ消す。旧 HolidaySelect には絶対触らない
    execute("DELETE FROM enumerations WHERE type = 'GanttHolidaySelect';")
    drop_table(:gantt_holiday_values)   if table_exists?(:gantt_holiday_values)
    drop_table(:gantt_project_holidays) if table_exists?(:gantt_project_holidays)
  end
end