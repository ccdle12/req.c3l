module req::http1;

import std::collections::set;
import std::time;

struct MonthIterator
{
    Month[12] months;
    usz idx;
    Month current;
}

fn void MonthIterator.init(&self)
{
    self.months =
    {
        JANUARY,
        FEBRUARY,
        MARCH,
        APRIL,
        MAY,
        JUNE,
        JULY,
        AUGUST,
        SEPTEMBER,
        OCTOBER,
        NOVEMBER,
        DECEMBER
    };

    self.current = JANUARY;
    self.idx = 0;
}

fn void MonthIterator.next(&self)
{
    if (self.idx > self.months.len - 1) return;
    self.idx++;
    self.current = self.months[self.idx];
}

macro void MonthIterator.@foreach(&self, ; @body(Month month))
{
    while (self.idx < self.months.len - 1)
    {
        @body(self.current);
        self.next();
    }
}

fn Month match_month(String input) => @pool()
{
    Month result;
    MonthIterator iter;
    iter.init();

    iter.@foreach(; Month month)
    {
        if (tnormalize_key(input) == tnormalize_key(iter.current.abbrev))
        {
            result = iter.current;
        }
    };


    return result;
}

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

fn bool is_valid_month(String month_str) => @pool()
{
    bool result = false;

    MonthIterator month_iter;
    month_iter.init();
    month_iter.@foreach(; Month month)
    {
        if (tnormalize_key(month_str) == tnormalize_key(month.abbrev)) result = true;
    };

    return result;
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
        if (date_time[7] != '-') return false;

        String month_str = date_time[8..10];
        if (!is_valid_month(month_str)) return false;

        Month month = match_month(month_str);
        if (day_num > month.days) return false;

        if (date_time[11] != '-') return false;

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
