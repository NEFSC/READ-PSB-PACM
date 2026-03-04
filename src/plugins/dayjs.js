import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import dayOfYear from 'dayjs/plugin/dayOfYear'
import customParseFormat from 'dayjs/plugin/customParseFormat'
import duration from 'dayjs/plugin/duration'
import minMax from 'dayjs/plugin/minMax'
import localizedFormat from 'dayjs/plugin/localizedFormat'
import isLeapYear from 'dayjs/plugin/isLeapYear'

dayjs.extend(utc)
dayjs.extend(dayOfYear)
dayjs.extend(customParseFormat)
dayjs.extend(duration)
dayjs.extend(minMax)
dayjs.extend(localizedFormat)
dayjs.extend(isLeapYear)
