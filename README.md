# Redmine Gantt Holiday plugin

A Redmine plugin that adds "Holiday Calendar", "Sticky Header", "Persistent View Settings", and "Bulk Parent-Child Issue Assignment (Oyakodon)" to the Gantt chart for Redmine 6.x.

- Manage holiday calendars by country/company and color-code Saturdays, Sundays, and holidays on the Gantt chart.
- Fix the date header at the top using an overlay method during vertical scrolling.
- Horizontal scrolling in the Gantt area via mouse drag (Grab to Scroll).
- Persist Gantt view settings (zoom, months, relations, progress line, columns) per user.
- Visually assign or detach multiple child issues to/from a parent issue right on the Gantt chart (Oyakodon feature).
- Supports 5 languages (English, Japanese, French, Korean, Chinese).

---

## Main Features

### 1. Holiday Calendar Management & Assignment
* **Multiple Calendars** — Add custom calendars (e.g., "Standard", "Company A", "Company B") and assign them per project.
* **CSV Import** — Easily import holiday CSV files, such as national holidays (Auto-detects Shift_JIS/UTF-8).
* **Official vs. Custom Holiday Control** — Unchecking an official holiday marks it as a working day (logical deletion), while custom entries are physically deleted.

### 2. Gantt Chart Optimization
* Saturdays are highlighted in light blue, and Sundays/holidays in light red (holidays configured as working days are excluded).
* Sticky date headers remain visible at the top when scrolling vertically (Overlay approach).
* Smooth "Grab to Scroll" via `mousedown` in the Gantt area (an well-behaved implementation that does not interrupt text selection or issue link clicks).

### 3. Persistent View Settings (Memory)
* Automatically saves zoom level, number of months, start date, and the toggle states of relations, progress lines (lightning lines), and selected columns to `User#preference`. Restores the exact previous view state even across projects. Includes a "Clear" button to reset all at once.

### 4. Oyakodon Feature — Bulk Parent-Child Assignment on Gantt
A lightweight edit mode on the Gantt chart to visually mass-assign or detach multiple child issues to/from a parent issue.

> 💡 **What is "Oyakodon" ? (For English Speakers / Overseas Developers)**
> *"Oyakodon"* literally means "Parent-and-Child Rice Bowl" (a traditional Japanese dish with chicken and egg). In this plugin, it is implemented as a playful development slang for **"Bulk Parent-Child Issue Assignment"** via the Gantt chart context menu.
> * **"Devour child issues" (子チケットを食べる)**: Starts the editing mode. The selected issue becomes the "Parent" (Bowl), and any issues you click on after that are treated as "Children" (Ingredients / *Gu*).
> * **"Itadakimasu" (いただきます / Let's eat)**: Commits the relationship. Updates `parent_issue_id` for all selected children at once (Up to 200 issues, safety guards included).
> * **"Gochisousama" (ごちそうさま / Thank you for the feast)**: Instantly detaches the child issue from its parent right from the context menu.

---

## Requirements

* **Redmine**: 6.0+ (6.1 compatible)
* **Ruby**: 3.2+
* **Rails**: 7.2
* **DB**: DB: PostgreSQL / MySQL / SQLite3

---

## Installation

```bash
# 1. Clone
cd /path/to/redmine/plugins
git clone https://github.com/seraph3000/redmine_gantt_holiday.git

# 2. Migration
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# 3. Asset Compile & Restart
bundle exec rake assets:clobber assets:precompile RAILS_ENV=production
systemctl restart httpd

```

---

## Uninstallation

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate NAME=redmine_gantt_holiday VERSION=0 RAILS_ENV=production
rm -rf plugins/redmine_gantt_holiday
systemctl restart httpd

```

---

## Changelog

v2.0.16 (2026-06)

* feature: Bulk parent-child relationship editing ("Oyakodon") and instant detachment ("Gochisousama") on the Gantt chart. Optimized the context menu for the Gantt view.

v2.0.15 (2026-05)

* Public release. Holiday color-coding, sticky headers, persistent settings, CSV import, and 5-language support.

---

## License

MIT License

## Author

**Seraph3000** — [GitHub](https://github.com/seraph3000)
