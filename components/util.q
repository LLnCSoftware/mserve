toString:{$[10=type x; x; string x]};
toSymbol:{`$ toString x} ;

/for any temporal type which includes a date
toYear:{ `year$ x};
toMonth:{ `month$ x} ;
toDate:{ `date$ x} ;
toWeek:{[dayOfWeek;x]                              /dayOfWeek (start day: 0=saturday 6=friday)
 d:dayOfWeek+ 7 xbar x; $[d>x; d-7; d]
 };
/ When monthOffset is zero this will give quarters which begin in Jan, Apr, Jul, Oct.
/ monthOffset should be zero, one, or two: one gives Feb, May, Aug, Nov; and two gives Mar, Jun, Sept, Dec.
/ Quarters will begin on the specified "dayOfMonth" which should be between 1 and 31. 
toQuarter:{[monthOffset;dayOfMonth;x]
  d:-1+(dayOfMonth & (`dd$ -1+ `date$ m+1))+ `date$ m:monthOffset+ 3 xbar `month$ x; $[d<=x; d; addMonthsNoOverflow[-3] d]
 };
/This is like .Q.addmonths, but when the specified day of month does not exist in the new month, 
/you get the last day of the new month instead of spilling over into the following month.
addMonthsNoOverflow:{-1+((`dd$y) & (`dd$ -1+ `date$ m+1))+ `date$ m:x+ `month$ y} ;

/This tests if a date range is contained within a single year, month, day, week, or quarter.
/Specify "convfn" as one of the above conversion functions to select the unit you want.
rangeWithin:{[beg;end;convfn] (convfn beg)=convfn end}

