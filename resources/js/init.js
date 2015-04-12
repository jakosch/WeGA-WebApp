/* Init functions */

$('.dropdown-secondlevel-nav').dropdownHover();

$("h1").fitText(1.4, {minFontSize: '42px', maxFontSize: '70px'});
$("h1.document").fitText(1.4, {minFontSize: '32px', maxFontSize: '40px'});

/* A wrapper function for creating select boxes */
/* Needs to be placed before the invoking call */
$.fn.facets = function ()
{
     this.selectize({
        plugins: ['remove_button'],
        hideSelected: true,
        onDropdownClose: function(e){
            var params = [];
            /* Set filters */
            $('.allFilter:visible option:selected').each(function() {
                var facet = $(this).parent().attr('name');
                var value = $(this).attr('value');
                /*console.log(facet + '=' + value);*/
                params.push(facet + '=' + value)
            })
            
            /* AJAX call for personal writings etc. */
            if($('li.resp-tab-active').length === 1) {
                var url = $('li.resp-tab-active a').attr('data-target') + '?'+params.join('&');
                var container = $('li.resp-tab-active a').attr('href')
                ajaxCall(container, url)
            }
            /* Refresh page for indices */
            else {
                self.location='?'+params.join('&')
            }
        }
    })
};

/*function facetsDropdownClose(facet) {
    console.log('foo')
};*/

/* only needed after ajax calls?!? --> see later */
/* needed on index page for the search box, as well */
//$('select').selectize({});
$('.allFilter select').facets();

/* Initialise popovers for notes */
$('.noteMarker').popover({
  'html': true,
  'placement': 'auto right',
  'content': function() {
      var noteID=$(this).attr('id').replace('Marker', '');
      var note=$('#' + noteID);
      return note.html();
  }
});

/* hide tabs with no respective div content */
$('li').has('a.deactivated').hide();

/* Responsive Tabs für person.html */
$('#details').easyResponsiveTabs({
    activate: function() {
        var activeTab = $('li.resp-tab-active a');
        var container = activeTab.attr('href');
        var url = activeTab.attr('data-target');
/*        console.log(url);*/

        // Do not load the page twice
        if ($(container).contents()[1].nodeType !== 1) {
            ajaxCall(container, url)
        }
        /* update facets */
/*        $('select').selectpicker({});*/
/*        $(href).unmask;*/
    }
});

/* Watch filters and highlight spans in text */
$('.allFilter input').change(
  function() {
    var key = $(this).attr('value');
    $('.' + key).toggleClass('hi')
  }
)

function ajaxCall(container,url) {
    $(container).mask();
    $(container).load(url, function(response, status, xhr) {
        if ( status == "error" ) {
            console.log(xhr.status + ": " + xhr.statusText);
        }
        else {
            /* update facets */
            $('.allFilter select').facets();
            /* Listen for click events on pagination */
            $('.page-link').on('click', 
                function() {
                    var activeTab = $('li.resp-tab-active a');
                    var baseUrl = activeTab.attr('data-target');
                    var url = baseUrl + $(this).attr('data-url');
                    console.log(url);
                    ajaxCall(container,url);
                }
            );
        }
    });
};

/* Farbige Support Badges im footer (page.html) */
$("[data-hovered-src]").hover(
    function(){
        $(this).data("original-src",$(this).attr("src"));
        $(this).attr("src",($(this).data("hovered-src")));
    },
    function(){
        $(this).data("hovered-src",$(this).attr("src"));
        $(this).attr("src",($(this).data("original-src")));
    } 
);

$("#datePicker").datepicker({
    dateFormat: "yy-mm-dd",
    minDate: "1810-02-26",
    maxDate: "1826-06-03",
    defaultDate: getDiaryDate(),
    changeMonth: true,
    changeYear: true,
    onSelect: function(dateText, inst) { 
        jump2diary(dateText)
    },
    beforeShowDay: function(date) {
        return [ checkValidDiaryDate(date)  ]
    }
});

function jump2diary(dateText) {
    var lang = getLanguage();
    var url = "http://localhost:8080/exist/apps/WeGA-WebApp/dev/api.xql?func=get-diary-by-date&format=json&date=" + dateText + "&lang=" + lang ;
    $.getJSON(url, function(data) {
        self.location=data.url + '.html';
    })
};

/* Exclude missing diary days */
function checkValidDiaryDate(date) {
    /* 5-20 April 1814 */
    /* 26-31. Mai */
    /* 1-9 Juni */
    /* 19-30 Juni */
    /* 1-26 Juli */
    var start1 =  new Date('04/05/1814');
    var end1 =  new Date('04/20/1814');
    var start2 =  new Date('05/26/1814');
    var end2 =  new Date('05/31/1814');
    var start3 =  new Date('06/01/1814');
    var end3 =  new Date('06/09/1814');
    var start4 =  new Date('06/19/1814');
    var end4 =  new Date('06/30/1814');
    var start5 =  new Date('07/01/1814');
    var end5 =  new Date('07/26/1814');
    return !(
        (date >= start1 && date <= end1) ||
        (date >= start2 && date <= end2) ||
        (date >= start3 && date <= end3) ||
        (date >= start4 && date <= end4) ||
        (date >= start5 && date <= end5)
    )
};

/* Get the current language from the top navigation */
function getLanguage() {
    return $('#navbarCollapse li.active:last a').html().toLowerCase()
};

/* Get the current diary date from the h1 heading */
function getDiaryDate() {
    var title = $('h1.document').html();
    var lang = getLanguage();
    var format;
    if(lang === 'de') { 
        format = "DD, dd. MM yy" 
    } 
    else { 
        format = "DD, MM dd, yy" 
    } ; 
    
    try { 
        var date = 
            $.datepicker.parseDate( format, title, {
              dayNamesShort: $.datepicker.regional[ lang ].dayNamesShort,
              dayNames: $.datepicker.regional[ lang ].dayNames,
              monthNamesShort: $.datepicker.regional[ lang ].monthNamesShort,
              monthNames: $.datepicker.regional[ lang ].monthNames
            });
    }
    catch(err) { date = '' }
    return date
};

/* Get the document ID from the breadcrumb */
function getID() {
    return $('.breadcrumb li:last').html()
};

/* Various functions */
function showEntries(that)
{
    $("#filter span").removeClass("activeFilterElement");
    $(that).addClass("activeFilterElement");
};

function changeIconCollapse(that)
{
    if ($(that).children("i").first().hasClass("fa-caret-up"))
    {
        $(that).children("i").first().removeClass("fa-caret-up");
        $(that).children("i").first().addClass("fa-caret-down");

        $(that).removeClass("inner-shadow-light");
        $(that).addClass("gradient-light");

    }

    else if ($(that).children("i").first().hasClass("fa-caret-down"))
    {
        $(that).children("i").first().removeClass("fa-caret-down");
        $(that).children("i").first().addClass("fa-caret-up");

        $(that).removeClass("gradient-light");
        $(that).addClass("inner-shadow-light");
    }

    else if ($(that).children("i").first().hasClass("fa-plus-circle"))
    {
        $(that).children("i").first().removeClass("fa-plus-circle");
        $(that).children("i").first().addClass("fa-minus-circle");
    }

    else if ($(that).children("i").first().hasClass("fa-minus-circle"))
    {
        $(that).children("i").first().removeClass("fa-minus-circle");
        $(that).children("i").first().addClass("fa-plus-circle");
    }
};

function addSearchOption(that)
{
    $(that).closest(".col-md-9").append("<div class='searchform'>"+$(that).closest(".searchform").html()+"</div>");
}
