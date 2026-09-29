-- 執行前先備份 daily_reports，並暫停所有舊版網頁的輸入。
-- 執行後，所有裝置請改用新版 index.html。
-- 本檔保留現有免登入權限；分店篩選不是存取權限隔離。
begin;

alter table public.daily_reports
  add column if not exists store_id text;
update public.daily_reports set store_id = 'fengshan' where store_id is null;
alter table public.daily_reports alter column store_id set default 'fengshan';
alter table public.daily_reports alter column store_id set not null;

-- 舊店沿用 115_7_1；新店使用 store2_115_11_1，避免 id 主鍵碰撞。
-- 同一家店同一天只能有一筆，供新版 upsert 使用。
create unique index if not exists daily_reports_store_date_unique
  on public.daily_reports (store_id, year, month, date);

-- 保留舊資料中的 0，不自動猜測哪些是休店或未填值。
-- 新版將空白日營業額寫成 NULL，明確輸入 0 則保存 0。

create or replace function public.set_daily_reports_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists daily_reports_updated_at on public.daily_reports;
create trigger daily_reports_updated_at
before update on public.daily_reports
for each row execute function public.set_daily_reports_updated_at();

commit;

-- 驗收：舊資料應全部屬於 fengshan，新店首次使用可為 0 筆。
select store_id, count(*) as report_count
from public.daily_reports group by store_id order by store_id;
