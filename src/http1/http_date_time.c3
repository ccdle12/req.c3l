module req::http1;

import std::collections::set;
import std::time;

fn HashSet{String} get_week_days(Allocator allocator)
{
    HashSet{String} week_days;
    week_days.init_with_values(allocator,
                                normalize_key(allocator, Weekday.MONDAY.abbrev),
                                normalize_key(allocator, Weekday.TUESDAY.abbrev),
                                normalize_key(allocator, Weekday.WEDNESDAY.abbrev),
                                normalize_key(allocator, Weekday.THURSDAY.abbrev),
                                normalize_key(allocator, Weekday.FRIDAY.abbrev),
                                normalize_key(allocator, Weekday.SATURDAY.abbrev),
                                normalize_key(allocator, Weekday.SUNDAY.abbrev));
    return week_days;
}

fn HashSet{String} get_months(Allocator allocator)
{
    HashSet{String} months;
    months.init_with_values(allocator,
                                normalize_key(allocator, Month.JANUARY.abbrev),
                                normalize_key(allocator, Month.FEBRUARY.abbrev),
                                normalize_key(allocator, Month.MARCH.abbrev),
                                normalize_key(allocator, Month.APRIL.abbrev),
                                normalize_key(allocator, Month.MAY.abbrev),
                                normalize_key(allocator, Month.JUNE.abbrev),
                                normalize_key(allocator, Month.JULY.abbrev),
                                normalize_key(allocator, Month.AUGUST.abbrev),
                                normalize_key(allocator, Month.SEPTEMBER.abbrev),
                                normalize_key(allocator, Month.OCTOBER.abbrev),
                                normalize_key(allocator, Month.NOVEMBER.abbrev),
                                normalize_key(allocator, Month.DECEMBER.abbrev));
    return months;
}

fn Month match_month(String input) => @pool()
{
    Month month;
    if (tnormalize_key(input) == tnormalize_key(Month.JANUARY.abbrev)) month = JANUARY;
    if (tnormalize_key(input) == tnormalize_key(Month.FEBRUARY.abbrev)) month = FEBRUARY;
    if (tnormalize_key(input) == tnormalize_key(Month.MARCH.abbrev)) month = MARCH;
    if (tnormalize_key(input) == tnormalize_key(Month.APRIL.abbrev)) month = APRIL;
    if (tnormalize_key(input) == tnormalize_key(Month.MAY.abbrev)) month = MAY;
    if (tnormalize_key(input) == tnormalize_key(Month.JUNE.abbrev)) month = JUNE;
    if (tnormalize_key(input) == tnormalize_key(Month.JULY.abbrev)) month = JULY;
    if (tnormalize_key(input) == tnormalize_key(Month.AUGUST.abbrev)) month = AUGUST;
    if (tnormalize_key(input) == tnormalize_key(Month.SEPTEMBER.abbrev)) month = SEPTEMBER;
    if (tnormalize_key(input) == tnormalize_key(Month.OCTOBER.abbrev)) month = OCTOBER;
    if (tnormalize_key(input) == tnormalize_key(Month.NOVEMBER.abbrev)) month = NOVEMBER;
    if (tnormalize_key(input) == tnormalize_key(Month.DECEMBER.abbrev)) month = DECEMBER;

    return month;
}

fn bool? validate_http_date_time(String date_time) => @pool()
{
        // According to RFC 1123, the datetime is ALWAYS 29 characters in length,
        // e.g. Wed, 21 Oct 2015 07:28:00 GMT
        if (date_time.len != 29) return false;

        String day = tnormalize_key(date_time[0..2]);

        if (!get_week_days(tmem).contains(day)) return false;
        if (date_time[3] != ',') return false;
        if (date_time[4] != SP) return false;

        // Date: <day>-<month>-<year>
        uint day_num = date_time[5..6].to_integer(uint)!;
        if (day_num > 31) return false;
        if (date_time[7] != '-') return false;

        String month_str = tnormalize_key(date_time[8..10]);
        if (!get_months(tmem).contains(month_str)) return false;

        Month month = match_month(month_str);
        if (day_num > month.days) return false;

        if (date_time[11] != '-') return false;

        // TODO: Is there a minimum year and maximum year?
        uint year = date_time[13..15].to_integer(uint)!;
        if (date_time[16] != SP) return false;

        // 5. Time: <24-hour>:<minute>:<second>
        if (date_time[17..18].to_integer(uint)! > 23) return false;
        if (date_time[19] != ':') return false;
        if (date_time[20..21].to_integer(uint)! > 59) return false;
        if (date_time[22] != ':') return false;
        if (date_time[23..24].to_integer(uint)! > 59) return false;

        if (date_time[25] != SP) return false;

        // Timezone can ONLY be GMT.
        if (date_time[26..28] != "GMT") return false;

        return true;
}
