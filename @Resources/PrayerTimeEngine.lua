function Update()
    -- v5.0: Now reads all settings dynamically from the skin's variables.

    local PrayTimes = {}

    function PrayTimes:new(method)
        local obj = {
            timeNames = { 'fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha' },
            methods = {
                MWL = { name = 'Muslim World League', params = { fajr = 18, isha = 17 } },
                ISNA = { name = 'Islamic Society of North America (ISNA)', params = { fajr = 15, isha = 15 } },
                Egypt = { name = 'Egyptian General Authority of Survey', params = { fajr = 19.5, isha = 17.5 } },
                Makkah = { name = 'Umm Al-Qura University, Makkah', params = { fajr = 18.5, isha = '90 min' } },
                Karachi = { name = 'University of Islamic Sciences, Karachi', params = { fajr = 18, isha = 18 } },
                Tehran = { name = 'Institute of Geophysics, University of Tehran', params = { fajr = 17.7, isha = 14, maghrib = 4.5 } },
                Jafari = { name = 'Shia Ithna-Ashari, Leva Institute, Qum', params = { fajr = 16, isha = 14 } }
            },
            defaultParams = { maghrib = '0 min', midnight = 'Standard' },
            settings = { imsak = '10 min', dhuhr = '0 min', asr = 'Standard', highLats = 'NightMiddle' },
            numIterations = 1,
        }
        setmetatable(obj, { __index = self })
        for m, config in pairs(obj.methods) do
            for name, value in pairs(obj.defaultParams) do
                if config.params[name] == nil then config.params[name] = value end
            end
        end
        obj.calcMethod = obj.methods[method] and method or 'MWL'
        local params = obj.methods[obj.calcMethod].params
        for name, value in pairs(params) do obj.settings[name] = value end
        return obj
    end
    function PrayTimes:sin(d) return math.sin(math.rad(d)) end
    function PrayTimes:cos(d) return math.cos(math.rad(d)) end
    function PrayTimes:tan(d) return math.tan(math.rad(d)) end
    function PrayTimes:arcsin(x) return math.deg(math.asin(x)) end
    function PrayTimes:arccos(x) if x > 1 or x < -1 then return nil end; return math.deg(math.acos(x)) end
    function PrayTimes:arccot(x) return math.deg(math.atan(1/x)) end
    function PrayTimes:fix(a, mode) if a == nil or a == 1/0 or a == -1/0 or a ~= a then return nil end; a = a - mode * math.floor(a / mode); return a < 0 and a + mode or a end
    function PrayTimes:fixangle(a) return self:fix(a, 360) end
    function PrayTimes:fixhour(a) return self:fix(a, 24) end
    function PrayTimes:eval(st) local val = tostring(st):match("([%-%d%.]+)"); return tonumber(val) or 0 end
    function PrayTimes:isMin(arg) return type(arg) == 'string' and arg:find('min') end
    function PrayTimes:timeDiff(time1, time2) if time1 == nil or time2 == nil then return nil end; return self:fixhour(time2 - time1) end
    function PrayTimes:julian(year, month, day) if month <= 2 then year = year - 1; month = month + 12 end; local A = math.floor(year / 100); local B = 2 - A + math.floor(A / 4); return math.floor(365.25 * (year + 4716)) + math.floor(30.6001 * (month + 1)) + day + B - 1524.5 end
    function PrayTimes:sunPosition(jd) local D = jd - 2451545.0; local g = self:fixangle(357.529 + 0.98560028 * D); local q = self:fixangle(280.459 + 0.98564736 * D); local L = self:fixangle(q + 1.915 * self:sin(g) + 0.020 * self:sin(2 * g)); local e = 23.439 - 0.00000036 * D; local RA = math.deg(math.atan2(self:cos(e) * self:sin(L), self:cos(L))) / 15.0; local eqt = q / 15.0 - self:fixhour(RA); local decl = self:arcsin(self:sin(e) * self:sin(L)); return decl, eqt end
    function PrayTimes:midDay(time) local _, eqt = self:sunPosition(self.jDate + time); return self:fixhour(12 - eqt) end
    function PrayTimes:sunAngleTime(angle, time, direction) local decl, _ = self:sunPosition(self.jDate + time); local noon = self:midDay(time); local acos_val = self:arccos((-self:sin(angle) - self:sin(decl) * self:sin(self.lat)) / (self:cos(decl) * self:cos(self.lat))); if acos_val == nil then return nil end; local t = (1/15.0) * acos_val; return noon + (direction == 'ccw' and -t or t) end
    function PrayTimes:asrTime(factor, time) local decl, _ = self:sunPosition(self.jDate + time); local angle = -self:arccot(factor + self:tan(math.abs(self.lat - decl))); return self:sunAngleTime(angle, time) end
    function PrayTimes:riseSetAngle(elevation) elevation = elevation or 0; return 0.833 + 0.0347 * math.sqrt(elevation) end
    function PrayTimes:dayPortion(times) for i, t in pairs(times) do times[i] = t / 24.0 end; return times end
    function PrayTimes:computePrayerTimes(times) times = self:dayPortion(times); local params = self.settings; local fajr = self:sunAngleTime(self:eval(params.fajr), times.fajr, 'ccw'); local sunrise = self:sunAngleTime(self:riseSetAngle(self.elv), times.sunrise, 'ccw'); local dhuhr = self:midDay(times.dhuhr); local asr = self:asrTime(params.asr == 'Hanafi' and 2 or 1, times.asr); local sunset = self:sunAngleTime(self:riseSetAngle(self.elv), times.sunset); local maghrib = self:sunAngleTime(self:eval(params.maghrib), times.maghrib); local isha = self:sunAngleTime(self:eval(params.isha), times.isha); return { fajr = fajr, sunrise = sunrise, dhuhr = dhuhr, asr = asr, sunset = sunset, maghrib = maghrib, isha = isha } end
    function PrayTimes:nightPortion(angle, night) local method = self.settings.highLats; local portion = 1/2.0; if method == 'AngleBased' then portion = 1/60.0 * angle elseif method == 'OneSeventh' then portion = 1/7.0 end; return portion * night end
    function PrayTimes:adjustHLTime(time, base, angle, night, direction) local portion = self:nightPortion(angle, night); local diff = self:timeDiff(time, base); if time == nil or diff == nil or diff > portion then time = base + (direction == 'ccw' and -portion or portion) end; return time end
    function PrayTimes:adjustHighLats(times) if times.sunrise == nil or times.sunset == nil then return times end; local params = self.settings; local nightTime = self:timeDiff(times.sunset, times.sunrise); times.fajr = self:adjustHLTime(times.fajr, times.sunrise, self:eval(params.fajr), nightTime, 'ccw'); times.isha = self:adjustHLTime(times.isha, times.sunset, self:eval(params.isha), nightTime); return times end
    function PrayTimes:adjustTimes(times) local params = self.settings; local tzAdjust = self.timeZone - self.lng / 15.0; for t, v in pairs(times) do if v ~= nil then times[t] = v + tzAdjust end end; if params.highLats ~= 'None' then times = self:adjustHighLats(times) end; if self:isMin(params.maghrib) then times.maghrib = times.sunset + self:eval(params.maghrib) / 60.0 end; if self:isMin(params.isha) then times.isha = times.maghrib + self:eval(params.isha) / 60.0 end; times.dhuhr = times.dhuhr + self:eval(params.dhuhr) / 60.0; return times end
    function PrayTimes:getRawTimes(date, coords, timezone, dst) self.lat = coords[1]; self.lng = coords[2]; self.elv = coords[3] or 0; self.timeZone = timezone + (dst or 0); self.jDate = self:julian(date.year, date.month, date.day) - self.lng / (15 * 24.0); local times = { fajr = 5, sunrise = 6, dhuhr = 12, asr = 13, sunset = 18, maghrib = 18, isha = 18 }; for i = 1, self.numIterations do times = self:computePrayerTimes(times) end; times = self:adjustTimes(times); return times end

 -- v6.0: Based on the user's correct and working code.
    -- Implements timezone adjustment directly into the progress bar calculation.

    -- --- Read settings from the .inc file ---
    local latitude = tonumber(SKIN:GetVariable('Latitude'))
    local longitude = tonumber(SKIN:GetVariable('Longitude'))
    local cityTimezone = tonumber(SKIN:GetVariable('Timezone'))
    local calcMethod = SKIN:GetVariable('CalcMethod')
    local asrMethod = SKIN:GetVariable('AsrMethod')

    local pt = PrayTimes:new(calcMethod)
    pt.settings.asr = asrMethod -- Override the Asr setting

    -- The prayer time calculation correctly uses the selected city's timezone.
    local todayForPrayerTimes = os.date('*t')
    local date = { year = todayForPrayerTimes.year, month = todayForPrayerTimes.month, day = todayForPrayerTimes.day }
    
    local rawTimes = pt:getRawTimes(date, {latitude, longitude}, cityTimezone, 0)
    
    local prayerNames = {'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'}
    local prayerTimesInMinutes = {}
    
    for i, name in ipairs(prayerNames) do
        local time = rawTimes[name:lower()]
        local h, m = 0, 0
        if time ~= nil then
            time = pt:fixhour(time + 0.5 / 60)
            if time ~= nil then
                h = math.floor(time)
                m = math.floor((time - h) * 60)
            end
        end
        SKIN:Bang('!SetVariable', name .. 'H', h)
        SKIN:Bang('!SetVariable', name .. 'M', m)
        prayerTimesInMinutes[name:lower()] = (h * 60) + m
    end

    -- --- NEW: Timezone-aware "Now" calculation for Progress Bar ---

    -- 1. Get the user's local PC timezone offset from GMT.
    local systemOffsetSeconds = os.date('%z')
    local systemTimezone = tonumber(systemOffsetSeconds) / 100

    -- 2. Get the user's local PC time in minutes.
    local localNowInMinutes = (todayForPrayerTimes.hour * 60) + todayForPrayerTimes.min

    -- 3. Calculate the difference in hours between the city and the user's PC.
    local timezoneDifference = cityTimezone - systemTimezone

    -- 4. Calculate the "virtual" current time for the selected city by applying the difference.
    -- This is the crucial step that synchronizes the progress bar with the countdown.
    local nowInMinutes = localNowInMinutes + (timezoneDifference * 60)

    -- The rest of the logic is the same as your working version, but it now uses the adjusted "nowInMinutes".
    local fajrMins = prayerTimesInMinutes['fajr']
    local dhuhrMins = prayerTimesInMinutes['dhuhr']
    local asrMins = prayerTimesInMinutes['asr']
    local maghribMins = prayerTimesInMinutes['maghrib']
    local ishaMins = prayerTimesInMinutes['isha']
    
    local nextPrayerMins
    if nowInMinutes <= fajrMins then nextPrayerMins = fajrMins
    elseif nowInMinutes <= dhuhrMins then nextPrayerMins = dhuhrMins
    elseif nowInMinutes <= asrMins then nextPrayerMins = asrMins
    elseif nowInMinutes <= maghribMins then nextPrayerMins = maghribMins
    elseif nowInMinutes <= ishaMins then nextPrayerMins = ishaMins
    else nextPrayerMins = fajrMins + 1440 end

    local startTimeMins
    if nowInMinutes <= fajrMins then startTimeMins = ishaMins - 1440
    elseif nowInMinutes <= dhuhrMins then startTimeMins = fajrMins
    elseif nowInMinutes <= asrMins then startTimeMins = dhuhrMins
    elseif nowInMinutes <= maghribMins then startTimeMins = asrMins
    elseif nowInMinutes <= ishaMins then startTimeMins = maghribMins
    else startTimeMins = ishaMins end

    local totalDuration = nextPrayerMins - startTimeMins
    local elapsedTime = nowInMinutes - startTimeMins
    
    local progress = 0
    if totalDuration > 0 then
        progress = (elapsedTime / totalDuration) * 100
        if progress > 100 then progress = 100 end
        if progress < 0 then progress = 0 end
    end
    
    SKIN:Bang('!SetVariable', 'Progress', progress)
    
    -- No need to call !Update or !Redraw here, the main skin handles that.
end