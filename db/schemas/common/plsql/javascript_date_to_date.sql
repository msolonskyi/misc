create or replace function javascript_date_to_date(pn_javascript_date in number, pv_timezone in varchar2)
return date
as
begin
  return cast((from_tz(cast(timestamp '1970-01-01 00:00:00 UTC' + pn_javascript_date * interval '1' second as timestamp), 'GMT') at time zone pv_timezone) as date);
end javascript_date_to_date;
/
