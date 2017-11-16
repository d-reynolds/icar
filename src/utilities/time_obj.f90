!>------------------------------------------------------------
!!  date / time module
!!
!!  Defines a Time_type object
!!
!!  Contains various utilities for working with dates and times.
!!  Utilities are capable of handling multiple model calendars.
!!
!!  @author
!!  Ethan Gutmann (gutmann@ucar.edu)
!!
!!------------------------------------------------------------
module time_object
    use time_delta_object, only : time_delta_t
    implicit none
    private

    integer, parameter :: MAXSTRINGLENGTH = 1024
    integer, parameter, public :: GREGORIAN=0, NOLEAP=1, THREESIXTY=2, NOCALENDAR=-1
    integer, parameter, public :: NON_VALID_YEAR = -9999

    !>------------------------------------------------------------
    !!  date / time Object
    !!
    !!  Time_type object stores date and time in a convenient object.
    !!  datetime is stored internally as both a modified julian day (or days since a known date)
    !!  and as a Y/M/D h:m:s integers
    !!
    !!------------------------------------------------------------
    type, public :: Time_type
        integer :: year_zero = 1800  ! reference date
        integer :: month_zero= 1
        integer :: day_zero  = 1
        integer :: calendar
        integer, dimension(13) :: month_start
        integer :: year, month, day, hour, minute, second

        double precision :: current_date_time = 0

      contains
        procedure, public  :: date        => calendar_date
        procedure, public  :: mjd         => get_mjd
        procedure, public  :: seconds     => get_seconds
        procedure, public  :: day_of_year => calc_day_of_year
        procedure, public  :: date_to_mjd => date_to_mjd
        procedure, public  :: as_string   => as_string
        procedure, public  :: equals      => equals_with_precision
        procedure, public  :: units       => units

        generic,   public  :: init        => time_init_c
        generic,   public  :: init        => time_init_i
        generic,   public  :: set         => set_from_string
        generic,   public  :: set         => set_from_date
        generic,   public  :: set         => set_from_mjd
        procedure, private :: time_init_c
        procedure, private :: time_init_i
        procedure, private :: set_from_string
        procedure, private :: set_from_date
        procedure, private :: set_from_mjd
        procedure, private :: set_calendar

        ! operator overloading to permit comparison of time objects as (t1 < t2), (t1 == t2) etc.
        procedure, private :: equal
        generic,   public  :: operator(==)   => equal
        procedure, private :: not_equal
        generic,   public  :: operator(/=)   => not_equal
        procedure, private :: greater_than
        generic,   public  :: operator(>)    => greater_than
        procedure, private :: greater_or_eq
        generic,   public  :: operator(>=)   => greater_or_eq
        procedure, private :: less_than
        generic,   public  :: operator(<)    => less_than
        procedure, private :: less_or_eq
        generic,   public  :: operator(<=)   => less_or_eq

        procedure, private :: addition
        generic,   public  :: operator(+)    => addition
        procedure, private :: difference
        generic,   public  :: operator(-)    => difference

    end type Time_type

contains

    !>------------------------------------------------------------
    !!  Initialize the time object
    !!
    !!  Set the object calendar and base year
    !!
    !!------------------------------------------------------------
    subroutine time_init_c(this, calendar_name, year_zero, month_zero, day_zero)
        implicit none
        class(Time_type) :: this
        character(len=*), intent(in) :: calendar_name
        integer, intent(in), optional :: year_zero, month_zero, day_zero

        integer :: i

        ! zero based month_starts (will have 1 added below)
        this%month_start = [0,31,59,90,120,151,181,212,243,273,304,334,365]

        call this%set_calendar(calendar_name)

        if (this%calendar == THREESIXTY) then
            do i=0,12
                this%month_start(i+1) = i*30
            end do
        endif

        this%month_start = this%month_start + 1

        if ( present(year_zero) ) then
            this%year_zero = year_zero
        endif
        if ( present(month_zero) ) then
            this%month_zero = month_zero
        endif
        if ( present(day_zero) ) then
            this%day_zero = day_zero
        endif

    end subroutine time_init_c

    !>------------------------------------------------------------
    !!  Initialize the time object
    !!
    !!  Set the object calendar and base year
    !!
    !!------------------------------------------------------------
    subroutine time_init_i(this, calendar, year_zero, month_zero, day_zero)
        implicit none
        class(Time_type) :: this
        integer, intent(in) :: calendar
        integer, intent(in), optional :: year_zero, month_zero, day_zero

        integer :: i

        ! zero based month_starts (will have 1 added below)
        this%month_start = [0,31,59,90,120,151,181,212,243,273,304,334,365]

        this%calendar = calendar

        if (this%calendar == THREESIXTY) then
            do i=0,12
                this%month_start(i+1) = i*30
            end do
        endif

        this%month_start = this%month_start + 1

        if ( present(year_zero) ) then
            this%year_zero = year_zero
        endif
        if ( present(month_zero) ) then
            this%month_zero = month_zero
        endif
        if ( present(day_zero) ) then
            this%day_zero = day_zero
        endif

    end subroutine time_init_i

    !>------------------------------------------------------------
    !!  Set the calendar from a given name
    !!
    !!  Looks at a calendar_name string to identify matches to known calendars
    !!  Known calendars are : 'gregorian', 'standard', '365-day', 'noleap', '360-day'
    !!  But only the first 5 characters are required.
    !!
    !!  Sets the object calendar attribute.
    !!
    !!------------------------------------------------------------
    subroutine set_calendar(this, calendar_name)
        implicit none
        class(Time_type) :: this
        character(len=*), intent(in) :: calendar_name

        this%calendar = NOCALENDAR

        select case (trim(calendar_name))
            case("proleptic_gregorian")
                this%calendar = GREGORIAN
            case("gregorian")
                this%calendar = GREGORIAN
            case("standard")
                this%calendar = GREGORIAN
            case("365-day")
                this%calendar = NOLEAP
            case("noleap")
                this%calendar = NOLEAP
            case("360-day")
                this%calendar = THREESIXTY
            case default
                this%calendar = NOCALENDAR
        end select

        if (this%calendar==NOCALENDAR) then
            ! in case there are odd characters tacked on the end (as seems to happen with some netcdf files?)
            select case (trim(calendar_name(1:5)))
                case("prole")
                    this%calendar = GREGORIAN
                case("grego")
                    this%calendar = GREGORIAN
                case("stand")
                    this%calendar = GREGORIAN
                case("365-d")
                    this%calendar = NOLEAP
                case("nolea")
                    this%calendar = NOLEAP
                case("360-d")
                    this%calendar = THREESIXTY
                case default
                    write(*,*) "Unknown Calendar: '", trim(calendar_name),"'"
                    write(*,*) "Acceptable names = "
                    write(*,*) "  'gregorian', 'standard', '365-day', 'noleap', '360-day'"
                    write(*,*) " "
                    stop
            end select
        endif

    end subroutine set_calendar


    !>------------------------------------------------------------
    !!  Return the current date number (seconds since reference time)
    !!
    !!  For a gregorian calendar, if no year is specified, this will be
    !!  a modified Julian day (*86400).  For all other calendars it will be
    !!  seconds since startyear/startmonth/startday
    !!
    !!------------------------------------------------------------
    function get_seconds(this) result(seconds)
        implicit none
        class(Time_type) :: this
        double precision :: seconds

        seconds = this%current_date_time * 86400.0D0
    end function get_seconds


    !>------------------------------------------------------------
    !!  Return the current date number (days since initial year)
    !!
    !!  For a gregorian calendar, if no year is specified, this will be
    !!  a modified Julian day.  For all other calendars it will be days since 0-1-1
    !!
    !!------------------------------------------------------------
    function get_mjd(this) result(mjd)
        implicit none
        class(Time_type) :: this
        double precision :: mjd

        mjd = this%current_date_time
    end function get_mjd

    !>------------------------------------------------------------
    !!  Calcualte the julian day number corresponding to a given year, month and day
    !!  in a gregorian calendar
    !!
    !!   Algorithm from Wikipedia: http://en.wikipedia.org/wiki/Julian_day
    !!   originally from Richards, E. G. (2013). Calendars. In S. E. Urban & P. K. Seidelmann, eds.
    !!                   Explanatory Supplement to the Astronomical Almanac, 3rd ed. (pp. 585–624).
    !!                   Mill Valley, Calif.: University Science Books. ISBN 978-1-89138-985-6
    !!                   p617-9
    !!
    !!------------------------------------------------------------
    function gregorian_julian_day(year, month, day, hour, minute, second) result(julian_day)
        implicit none
        integer, intent(in) :: year, month, day, hour, minute, second
        double precision :: julian_day
        double precision :: d,m,y
        integer :: a,b

        a = (14-month)/12
        y = year+4800-a
        m = month+12*a-3

        ! Gregorian calendar
        b = day + floor((153*m+2)/5) + 365*y + floor(y/4) - floor(y/100) + floor(y/400) - 32045

        ! Julian calendar
        ! b = day + floor(153*m+2/5) + 365*y + floor(y/4) - 32083

        julian_day = b + (((second/60d+0)+minute)/60d+0 + hour-12)/24.0

    end function

    !>------------------------------------------------------------
    !!  Convert a Year, Month, Day, hour, minute, second into a single number
    !!
    !!  This number will be a Modified Julian Day for the default gregorian calendar
    !!  or it will be a number of days since whatever the initial year was
    !!
    !!------------------------------------------------------------
    function date_to_mjd(this, year, month, day, hour, minute, second)
        implicit none
        class(Time_type), intent(in) :: this
        integer, intent(in) :: year, month, day, hour, minute, second
        double precision :: date_to_mjd

        if (this%calendar==GREGORIAN) then
            date_to_mjd = gregorian_julian_day(year, month, day, hour, minute, second)

            date_to_mjd = date_to_mjd - gregorian_julian_day(this%year_zero, this%month_zero, this%day_zero, 0, 0, 0)

        else if (this%calendar==NOLEAP) then
            date_to_mjd = (year-this%year_zero)*365 + this%month_start(month)-1 + day-1 + (hour + (minute+second/60d+0)/60d+0)/24d+0
        else if (this%calendar==THREESIXTY) then
            date_to_mjd = (year-this%year_zero)*360 + this%month_start(month)-1 + day-1 + (hour + (minute+second/60d+0)/60d+0)/24d+0
        end if

    end function date_to_mjd

    !>------------------------------------------------------------
    !!  Calculate the year, month, day, hour, minute second for the current date_time object
    !!
    !!  Y, M, D, h, m, s are modified on return
    !!  arguably, seconds should be a real number, not an integer...
    !!
    !!------------------------------------------------------------
    subroutine calendar_date(this, year, month, day, hour, minute, second)
        implicit none
        class(Time_type), intent(in) :: this
        integer, intent(out) :: year, month, day, hour, minute, second

        integer :: y=4716,j=1401,m=2,n=12,r=4,p=1461
        integer :: v=3,u=5,s=153,w=2,B=274277,C=-38
        integer ::f,e,g,h, jday
        double precision :: day_fraction, mjd

        mjd = this%current_date_time+1d-5 ! add less than one second

        !------------------------------------------------------------
        !
        ! Calculate the dates for a Gregorian Calendar
        !
        !------------------------------------------------------------
        if (this%calendar==GREGORIAN) then
            jday = nint(mjd + gregorian_julian_day(this%year_zero, this%month_zero, this%day_zero, 0, 0, 0))

            f = jday+j+(((4*jday+B)/146097)*3)/4+C
            e = r*f+v
            g = mod(e,p)/r
            h = u*g+w
            day   = mod(h,s)/u+1
            month = mod(h/s+m,n)+1
            year  = e/p-y+(n+m-month)/n

        !------------------------------------------------------------
        !
        ! Calculate the dates for a No leap Calendar
        !
        !------------------------------------------------------------
        else if (this%calendar==NOLEAP) then
            year=floor(mjd/365)
            day_fraction=mjd - year*365+1
            do f=1,12
                if (day_fraction>this%month_start(f)) then
                    month=f
                endif
            end do
            day = floor(day_fraction - this%month_start(month))+1
            year=year+this%year_zero

        !------------------------------------------------------------
        !
        ! Calculate the dates for a 360-day Calendar
        !
        !------------------------------------------------------------
        else if (this%calendar==THREESIXTY) then
            year=floor(mjd/360)
            day_fraction=mjd - year*360+1
            do f=1,12
                if (day_fraction>this%month_start(f)) then
                    month=f
                endif
            end do
            day = floor(day_fraction - this%month_start(month))+1
            year=year+this%year_zero
        end if

        !------------------------------------------------------------
        !
        ! Calculate the hour/minute/second for any calendar
        !
        !------------------------------------------------------------
        day_fraction=mod(mjd,1.0)
        hour=floor(day_fraction*24)

        day_fraction=day_fraction*24-hour
        minute=floor(day_fraction*60)

        day_fraction=day_fraction*60-minute
        second = nint((day_fraction-(24d0*60*1d-5))*60)

    end subroutine calendar_date


    !>------------------------------------------------------------
    !!  Return the day of the year corresponding to the current date_time
    !!
    !!  Calculate the day of the year from a "modified julian day" or other days since date
    !!
    !!------------------------------------------------------------
    function calc_day_of_year(this)
        implicit none
        class(Time_type) :: this
        real :: calc_day_of_year

        integer :: year, month, day, hour, minute, second

        select case (this%calendar)
            ! a gregorian calendar requires a call to get the current year start date_time
            ! (could probably be done more efficiently...)
            case (GREGORIAN)
                call this%date(year, month, day, hour, minute, second)
                calc_day_of_year = this%current_date_time - this%date_to_mjd(year, 1,1,0,0,0)

            !! other calendars are easy, just mod by the number of days in a year
            case (NOLEAP)
                calc_day_of_year = mod(this%current_date_time,365.0)
            case (THREESIXTY)
                calc_day_of_year = mod(this%current_date_time,360.0)
        end select

    end function calc_day_of_year

    !>------------------------------------------------------------
    !!  Set the current date based on an input string
    !!
    !!  Convert an input date string in the form YYYY/MM/DD or YYYY/MM/DD hh:mm:ss
    !!
    !!------------------------------------------------------------
    subroutine set_from_string(this, date)
        implicit none
        class(Time_type), intent(inout) :: this
        character (len=*), intent(in) :: date

        read(date(1:4), *) this%year
        read(date(6:7), *) this%month
        read(date(9:10),*) this%day

        if(len_trim(date) <= 18) then
            this%second  = 0
            this%minute  = 0
            this%hour    = 0
        else
            read(date(12:13), *) this%hour
            read(date(15:16), *) this%minute
            read(date(18:19), *) this%second
        endif

        this%current_date_time = this%date_to_mjd(this%year, this%month, this%day, this%hour, this%minute, this%second)
    end subroutine set_from_string

    !>------------------------------------------------------------
    !!  Set the current date based on an input set of integer date components
    !!
    !!  Set the datetime object to a given input date (Year, Month, Day, Hour, Minute, second)
    !!
    !!------------------------------------------------------------
    subroutine set_from_date(this, year, month, day, hour, minute, second)
        implicit none
        class(Time_type), intent(inout) :: this
        integer, intent(in) :: year, month, day
        integer, intent(in), optional :: hour, minute, second
        integer :: set_hour, set_minute, set_second

        set_hour=0; set_minute=0; set_second=0
        if (present(hour))   set_hour = hour
        if (present(minute)) set_minute = minute
        if (present(second)) set_second = second

        this%current_date_time = this%date_to_mjd(year, month, day, set_hour, set_minute, set_second)
        this%year   = year
        this%month  = month
        this%day    = day
        this%hour   = set_hour
        this%minute = set_minute
        this%second = set_second

    end subroutine set_from_date

    !>------------------------------------------------------------
    !!  Set the current date based on an input day number (e.g. Modified Julian day)
    !!
    !!  Set the datetime object to a given input datetime number
    !!
    !!------------------------------------------------------------
    subroutine set_from_mjd(this, days)
        implicit none
        class(Time_type), intent(inout) :: this
        double precision, intent(in) :: days
        integer :: year, month, day, hour, minute, second

        this%current_date_time = days

        call this%date(year, month, day, hour, minute, second)
        this%year   = year
        this%month  = month
        this%day    = day
        this%hour   = hour
        this%minute = minute
        this%second = second

    end subroutine set_from_mjd

    !>------------------------------------------------------------
    !!  Create a formated "units" string for this object
    !!
    !!  For example "days since 1858-11-17 00:00:00"
    !!
    !!------------------------------------------------------------
    function units(this)
        implicit none
        class(Time_type), intent(in)   :: this
        character(len=MAXSTRINGLENGTH) :: units

        write(units, '("days since ",i4,"-",i2.2,"-",i2.2," 00:00:00")') &
                this%year_zero,this%month_zero,this%day_zero

    end function units

    !>------------------------------------------------------------
    !!  Convert the date object into a string in the 0-filled format : "YYYY/MM/DD hh:mm:ss"
    !!
    !!------------------------------------------------------------
    function as_string(this, input_format) result(pretty_string)
        implicit none
        class(Time_type), intent(in) :: this
        character(len=*), intent(in), optional :: input_format
        character(len=MAXSTRINGLENGTH) :: pretty_string
        character(len=MAXSTRINGLENGTH) :: format
        integer :: i

        associate(year  => this%year,   &
                  month => this%month,  &
                  day   => this%day,    &
                  hour  => this%hour,   &
                  minute=> this%minute, &
                  second=> this%second  &
                  )

        if (present(input_format)) then
            format = input_format
        else
            ! this is the default format string to generate "YYYY/MM/DD hh:mm:ss"
            format = '(I4,A1,I2,A1,I2,A1,I2,A1,I2,A1,I2)'
        endif

        ! this and the format statement above are the important bits
        write(pretty_string, format) year,'/',month,'/',day,'_',hour,':',minute,":",second

        ! fill missing digits with '0'
        do i=1,len_trim(pretty_string)
            select case (pretty_string(i:i))
                case (' ')
                    pretty_string(i:i) = '0'
                case ('_')
                    pretty_string(i:i) = ' '
            end select
        end do

        end associate

    end function as_string

    !>------------------------------------------------------------
    !!  Test that time 1 is greater than time 2
    !!
    !!  Used to implement the [>] operator
    !!  If the two input times have the same refernce calender, it just returns
    !!  > on the internal time representation between the two
    !!  Otherwise it retrieves the year, month, day, ... from both and checks for
    !!  > on all elements sequentially (year, then month, then day...)
    !!
    !!------------------------------------------------------------
    function greater_than(t1, t2)
        implicit none
        class(Time_type), intent(in) :: t1, t2
        logical :: greater_than

        greater_than = .False.

        ! note if calendars are the same, can just return mjd delta...
        if ((t1%calendar == t2%calendar).and.(t1%year_zero == t2%year_zero)) then
            greater_than = (t1%current_date_time > t2%current_date_time)
            return
        endif

        if (t1%year > t2%year) then
            greater_than = .True.
        else if (t1%year == t2%year) then
            if (t1%month > t2%month) then
                greater_than = .True.
            else if (t1%month == t2%month) then
                if (t1%day > t2%day) then
                    greater_than = .True.
                else if (t1%day == t2%day) then
                    if (t1%hour > t2%hour) then
                        greater_than = .True.
                    else if (t1%hour == t2%hour) then
                        if (t1%minute > t2%minute) then
                            greater_than = .True.
                        else if (t1%minute == t2%minute) then
                            if (t1%second > t2%second) then
                                greater_than = .True.
                            else if (t1%second == t2%second) then
                                greater_than = .False.
                            endif
                        endif
                    endif
                endif
            endif
        endif

    end function greater_than

    !>------------------------------------------------------------
    !!  Test that time 1 is greater than or equal to time 2
    !!
    !!  Used to implement the [>=] operator
    !!  If the two input times have the same refernce calender, it just returns
    !!  >= on the internal time representation between the two
    !!  Otherwise it retrieves the year, month, day, ... from both and checks for
    !!  >= on all elements sequentially (year, then month, then day...)
    !!
    !!------------------------------------------------------------
    function greater_or_eq(t1, t2)
        implicit none
        class(Time_type), intent(in) :: t1, t2
        logical :: greater_or_eq

        greater_or_eq = .False.

        ! note if calendars are the same, can just return mjd delta...
        if ((t1%calendar == t2%calendar).and.(t1%year_zero == t2%year_zero)) then
            if ((t1%month_zero == t2%month_zero).and.(t1%day_zero == t2%day_zero)) then
                greater_or_eq = (t1%current_date_time >= t2%current_date_time)
                return
            endif
        endif


        if (t1%year > t2%year) then
            greater_or_eq = .True.
        else if (t1%year == t2%year) then
            if (t1%month > t2%month) then
                greater_or_eq = .True.
            else if (t1%month == t2%month) then
                if (t1%day > t2%day) then
                    greater_or_eq = .True.
                else if (t1%day == t2%day) then
                    if (t1%hour > t2%hour) then
                        greater_or_eq = .True.
                    else if (t1%hour == t2%hour) then
                        if (t1%minute > t2%minute) then
                            greater_or_eq = .True.
                        else if (t1%minute == t2%minute) then
                            if (t1%second >= t2%second) then
                                greater_or_eq = .True.
                            endif
                        endif
                    endif
                endif
            endif
        endif

    end function greater_or_eq


    !>------------------------------------------------------------
    !!  Test that time 1 is equal to time 2
    !!
    !!  Used to implement the [==] operator
    !!  If the two input times have the same refernce calender, it just returns
    !!  == on the internal time representation between the two
    !!  Otherwise it retrieves the year, month, day, ... from both and checks for
    !!  equality on all elements
    !!
    !!------------------------------------------------------------
    function equal(t1, t2)
        implicit none
        class(Time_type), intent(in) :: t1, t2
        logical :: equal

        equal = .False.

        ! note if calendars are the same, can just return mjd delta...
        if ((t1%calendar == t2%calendar).and.(t1%year_zero == t2%year_zero)) then
            ! if the time delta is < ~one second, then return true
            equal = (abs(t1%current_date_time - t2%current_date_time) < 1.1575e-05)
            return
        endif

        if ((t1%year == t2%year).and.(t1%month == t2%month).and.(t1%day == t2%day)      &
            .and.(t1%hour == t2%hour).and.(t1%minute == t2%minute).and.(t1%second == t2%second)) then
            equal = .True.
        endif

    end function equal


    !>------------------------------------------------------------
    !!  Test that time 1 is not equal to time 2
    !!
    !!  Used to implement the [/=] operator
    !!  Simply returns not ==
    !!
    !!------------------------------------------------------------
    function not_equal(t1, t2)
        implicit none
        class(Time_type), intent(in) :: t1, t2
        logical :: not_equal

        not_equal = .not.equal(t1,t2)

    end function not_equal


    !>------------------------------------------------------------
    !!  Test that time 1 is less than or equal to time 2
    !!
    !!  Used to implement the [<=] operator
    !!  Simply returns not >
    !!
    !!------------------------------------------------------------
    function less_or_eq(t1, t2)
        implicit none
        class(Time_type), intent(in) :: t1, t2
        logical :: less_or_eq

        less_or_eq = .not.greater_than(t1,t2)

    end function less_or_eq

    !>------------------------------------------------------------
    !!  Test that time 1 is less than time 2
    !!
    !!  Used to implement the [<] operator
    !!  Simply returns not >=
    !!
    !!------------------------------------------------------------
    function less_than(t1, t2)
        implicit none
        class(Time_type), intent(in) :: t1, t2
        logical :: less_than

        less_than = .not.greater_or_eq(t1,t2)

    end function less_than

    !>------------------------------------------------------------
    !!  Compare that two time objects are equal to within a specified precision
    !!
    !!  If precision is not specified, just returns the == operator result
    !!  If precision is specified, returns true if abs(t1-t2) <= precision
    !!
    !!------------------------------------------------------------
    function equals_with_precision(t1,t2, precision) result(equals)
        implicit none
        class(Time_type),    intent(in) :: t1, t2
        class(time_delta_t), intent(in), optional :: precision
        logical :: equals
        type(time_delta_t) :: dt

        if (.not.present(precision)) then
            equals = (t1%equal(t2))
        else
            dt = t1 - t2
            equals = abs(dt%seconds()) <= precision%seconds()
        endif

    end function equals_with_precision


    !>------------------------------------------------------------
    !!  Subtract two times and return a time_delta object
    !!
    !!------------------------------------------------------------
    function difference(t1, t2) result(dt)
        implicit none
        class(Time_type), intent(in) :: t1, t2
        type(time_delta_t) :: dt

        type(Time_type) :: temp_time
        integer :: year, month, day, hour, minute, second

        if (((t1%calendar == t2%calendar).and.(t1%year_zero == t2%year_zero)) &
            .and.((t1%month_zero == t2%month_zero).and.(t1%day_zero == t2%day_zero))) then

            call dt%set(seconds=(t1%mjd() - t2%mjd()) * 86400.0D0)
        else
            ! if the two time object reference calendars don't match
            ! create a new time object with the same referecnce as t1
            ! then copy the date/time data into it from t2 before computing the time delta
            call temp_time%init(t1%calendar,t1%year_zero,t1%month_zero,t1%day_zero)
            call t2%date(year, month, day, hour, minute, second)
            call temp_time%set(year, month, day, hour, minute, second)

            call dt%set(seconds=((t1%mjd() - temp_time%mjd()) * 86400.0D0))
        endif

    end function difference

    !>------------------------------------------------------------
    !!  Add a given time delta to a time object
    !!
    !!  returns a new time object
    !!
    !!------------------------------------------------------------
    function addition(t1, dt) result(t2)
        implicit none
        class(Time_type),   intent(in) :: t1
        type(time_delta_t), intent(in) :: dt
        type(Time_type) :: t2

        t2 = t1 ! set calendar startyear, etc.

        call t2%set(t1%mjd() + dt%days())

    end function addition

end module time_object