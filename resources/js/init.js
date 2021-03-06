/* Init functions */

$('.dropdown-secondlevel-nav').dropdownHover();

/* Adjust font size of h1 headings */
$.fn.h1FitText = function () {
    if ($(this).hasClass('document')) { $(this).fitText(1.4, {minFontSize: '32px', maxFontSize: '40px'}) }
    else if ($(this).hasClass('home')) { $(this).fitText(1.4, {minFontSize: '36px', maxFontSize: '48px'}) }
    else if ($(this).html().length > 30) { $(this).fitText(1.4, {minFontSize: '32px', maxFontSize: '40px'}) }
    else $(this).fitText(1.4, {minFontSize: '36px', maxFontSize: '48px'});
};

$.fn.extend({
    // set the white-space to normal (instead of nowrap) for long spans of text, see https://github.com/Edirom/WeGA-WebApp/issues/205
    setTextWrap: function() {
        return this.each( function(a,b) {
            if(b.innerText.length > 50) {$(b).css({"white-space":"normal"})}
        })
    }
});

/* A wrapper function for creating select boxes */
/* Needs to be placed before the invoking call */
$.fn.facets = function ()
{
    $(this).each( function(a, b) {
        $(b).selectize({
            plugins: ['remove_button'],
            hideSelected: true,
            onChange: function(e){
                /* Get active facets to append as URL params */
                var params = active_facets();
                //console.log(params.toString());
                updatePage(params);
            },
            preload: "focus",
            valueField: "value",
            labelField: "label",
            sortField: "label",
            searchField: ["label"],
            loadThrottle: 100,
            load: function(query, callback) {
                if (query.length) return callback();
                
                var params = active_facets(),
                    url = $(b).attr('data-api-url') + params.toString() + '&func=facets&format=json&facet=' + $(b).attr('name') + '&docID=' + $(b).attr('data-doc-id') + '&docType=' + $(b).attr('data-doc-type') + '&lang=' + getLanguage();
                $.ajax({
                    url: url,
                    type: 'GET',
                    dataType: 'json',
                    error: function() {
                        callback();
                    },
                    success: function(res) {
                        callback(res);
                    }
                });
            },
            render: {
                option: function (item, escape) {
                    return '<div>' + escape(item.label) + ' (' + escape(item.frequency) + ')</div>';
                }
            }
        })
    })
};

$.fn.rangeSlider = function () 
{
    this.ionRangeSlider({
        min: +moment($(this).attr('data-min-slider')),
        max: +moment($(this).attr('data-max-slider')),
        from: +moment($(this).attr('data-from-slider')),
        to: +moment($(this).attr('data-to-slider')),
        grid: true,
        step: 100,
        type: "double",
        //force_edges: true,
        grid_num: 3,
        keyboard: true,
        prettify: function (num) {
            var m = moment(num).locale("de");
            return m.format("D. MMM YYYY");
        },
        onFinish: function (data) {
            /* Get active facets to append as URL params */
            var params = active_facets(),
                newFrom = moment(data.from).locale("de").format("YYYY-MM-DD"),
                newTo = moment(data.to).locale("de").format("YYYY-MM-DD");
            
            /* 
             * Overwrite date params with new values from the slider 
             * when the new values equal the min/max values, reset to the empty string
             */
            params['fromDate'] = (data.from != data.min)? newFrom: '';
            params['toDate'] = (data.to != data.max)? newTo: '';
            
            updatePage(params);
        }
    });
};

$.fn.obfuscateEMail = function () {
    if($(this).length === 0) {}
    else {
        var e = $(this).html().substring(0, $(this).html().indexOf('[')).trim(),
            t = $(this).html().substring($(this).html().indexOf(']') +1).trim(),
            r = '' + e + '@' + t ;
        $(this).attr('href',' mailto:' +r).html(r);
    }
}

/* Load portraits via AJAX */
$.fn.loadPortrait = function () {
    $(this).each( function(a, b) {
        var url = $(b).children('a').attr('href').replace('.html', '/portrait.html');
        $(b).load(url + " a");
    })
};

/* Initialise datepicker for diaries */
$.fn.initDatepicker = function () {
    // set language for datepicker widget
    var lang = getLanguage();
    if(lang === 'de') { $.datepicker.setDefaults( $.datepicker.regional[ "de" ] ) }
    else { $.datepicker.setDefaults( $.datepicker.regional[ "" ]) }
    
    $(this).each(function(a,b) {
        $(b).datepicker({
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
        })
    })
};

/* 
 * Activate bootstrap remote nav tabs (on letters) 
 * "For further details see editorial"  
 */
$('#transcription a[href$=#editorial]').on('click', function (e) {
    // code taken from the bootstrap remote nav tabs plugin
    var url = $(e)[0].target.href,
        hash = url.substring(url.indexOf('#')+1),
        hasTab = $('[data-toggle=tab][href*='+hash+']'),
        hasAccordion = $('[data-toggle=collapse][href*='+hash+']');

    if (hasTab) {
        hasTab.tab('show');
    }
    
    if (hasAccordion) {
        // for some reason we cannot execute the 'show' event for an accordion properly, so here's a workaround
        if (hasAccordion[0] != $('[data-toggle=collapse]:first')[0]) {
            hasAccordion.click();
        }
    }
});

/* Run Google Code Prettifyer for code examples */
$.fn.googlecodeprettify = function () {
    prettyPrint();
}

$('.prettyprint').googlecodeprettify();

// remove popovers when clicking somewhere
$('body').on('click touchstart', function (e) {
    $('[data-original-title]').each(function () {
        //the 'is' for buttons that trigger popups
        //the 'has' for icons within a button that triggers a popup
        if (!$(this).is(e.target) && $(this).has(e.target).length === 0 && $('.popover').has(e.target).length === 0) {
            $(this).popover('hide');
        }
    });
});

/*
 * hide/reveal sub items of the table of contents of the Guidelines and Wikipedia
 */
$('.toggle-toc-item').on('click', toggleTocItems);
$('.toggle-toc-item').each(toggleTocItems);

/*
 * used for Guidelines TOC as well as for Wikipedia
 */
function toggleTocItems() {
    var subItem = $(this).siblings('ul');
    if(subItem.length === 1) {
        subItem.toggle();
        $('ul', subItem).toggle();
        $('i', this).toggle();
    }
    else {
        $('i', this).hide();
    }
};

/* 
 * callback function for removing the filter container from the AJAX page
 * this is called by the nav-tabs remote data plugin via the data-tab-callback attribute on the documents page (once)
 * as well as ajaxCall() (all subsequent calls by clicks on the pagination).
 * At present this is only needed for backlinks. 
 */
function removeFilter(html, trigger, container, data) {
    /* currently, we simply remove all filters  */
    $('.col-md-3', html).remove();
    
    /* and adjust the width of the remains  */
    html.removeClass('row');
    $('.col-md-9', html).removeClass('col-md-9 col-md-pull-3');
    
    /* 
     * Load portraits via AJAX
     * NB: Needed when called via data-tab-callback attribute
     */
    $('.searchResults .portrait', html).loadPortrait();
    
    /* 
     * Listen for click events on pagination
     * NB: Needed when called via data-tab-callback attribute
     * trigger is the clicked nav-tab (e.g. "backlinks")  
     */
    if(trigger.length !== 0) {
        $('.page-link', html).on('click', 
            function() {
                $(this).activatePagination(trigger.attr('href'));
            }
        );
    }
};

/*
 * set the right tab and location for person pages
 */
$.fn.toggleTab = function () {
    var tabHash = location.hash,
        tabRef,
        target;
    
    /* make "biographies" the default if no fragment identifier is given */
    if($(tabHash).length === 0) { target = '#biographies' }
    
    /* 
     * targets within biographies, e.g. wikipediaText, need special treatment
     * since the nested Bootstrap remote data tabs plugin prefixes those targets with "bs-tab-"
     */
    else if($('#biographies ' + tabHash).length !== 0) { 
        target = '#biographies';
        /* adjust location.hash */
        if(history.pushState) {
            history.pushState(null, null, '#bs-tab-' + tabHash);
        }
        else {
            location.hash = '#bs-tab-' + tabHash;
        }
    }
    
    /* check for a valid fragment */
    else if($(tabHash).length !== 0) { target = tabHash }
    
    /* make "biographies" the default if no _valid_ fragment identifier is given */
    else { target = '#biographies' }
    
    /* 
     * now walk through the tabs and containers 
     * and set the active class appropriately 
     */
    $(this).each(function(n,tab) {
        tabRef = tab.href.substring(tab.href.indexOf('#'));
        if(tabRef == target) {
            $(tab).parent().addClass('resp-tab-active');
            $(tabRef).addClass('resp-tab-content-active');
        }else {
            $(tab).parent().removeClass('resp-tab-active');
            $(tabRef).removeClass('resp-tab-content-active');
            $(tabRef).hide();
        }
    });
    if($(this).length !== 0) { activateTab(); }
    
    return this;
};

$.fn.A090280 = function () {
    if(getID() === 'A090280') {
        $(this).addClass('bg-info');
        $(this).css({'margin-bottom': '0px'});
    }
};

/* Some special treatment of headings here */
$('h3').A090280();

// load and activate person tab
function activateTab() {
    var activeTab = $('li.resp-tab-active a'),
        container = activeTab.attr('href'),
        url = activeTab.attr('data-target');

        // Do not load the page twice
        if ($(container).contents().length === 1 || $(container).contents()[1].nodeType !== 1) {
            ajaxCall(container, url)
        }
        /* update facets */
/*        $('select').selectpicker({});*/
/*        $(href).unmask;*/
};

/*
 * Grab the URL from the $container$/@data-ref and replace the container div with the AJAX response
 * Makes a nice popover for previews of pages :)
 */
$.fn.preview_popover = function() {
    var url = $(this).attr('data-ref').replace('.html', '/popover.html'),
        container = $(this),
        popover_node = container.parents('div.popover'),
        popover_data;
    $.ajax({
        url: url,
        success: function(response){
            var source = $(response),
                title = source.find('h3').html(),
                content = source.children();
            $('.item-title', container).html(title);
            $('.item-content', container).html(content);
            $('h3.media-heading', container).remove(); // remove relicts of headings
            
            /*  when this is the last div container we push it to the popover and show it
             *  unfinished ajax calls will still update the popover, though.
             */
            if(container.next().length === 0) {
                popover_data = popover_node.data('bs.popover');
                popover_data.options.content = container.parents('div.popover-content').children();
                popover_node.popover('show');
            }
            
            $('.portrait', container).loadPortrait(); // AJAX load person portraits*/
        }
    });
};

/* 
 * Create initial popover for notes and previews 
 * with template from page.html#carousel-popover for the content
 */
$('.preview, .noteMarker').on('click', function() {
    $(this).popover({
        "html": true,
        "trigger": "manual",
        "container": 'body',
        'placement': 'auto top',
        "title": "Loading …", // This is just a dummy title otherwise the content function will be called twice, see  https://github.com/twbs/bootstrap/issues/12563
        "content": popover_template
    });
    $(this).popover('show');
    
    /* Need to call this after popover('show') to get access to the popover options in a later step (in preview_popover) */
    popover_callBack.call($(this));
    
    /* Return false to suppress the default link mechanism on html:a */
    return false;
});

/*
 * A simple template for the popover based on page.html#carousel-popover
 * NB: we do not make use of the generic popover-title since we want 
 * to insert all AJAX content simply into popover-content
 */
function popover_template() {
    var carouselID = "carousel" + $.now(),
        template = $('#carousel-popover').clone().attr('id', carouselID).removeAttr('style');
    
    $('.carousel-indicators li', template).attr('data-target', '#'+carouselID);
    $('a.carousel-control', template).attr('href', '#'+carouselID);
    $('.carousel-indicators, a.carousel-control', template).hide();
    template.removeClass('hidden');
    return template;
};

/*
 * Prepare the container divs and the carousel controls (if needed) for the popover
 * because we are not using the default bootstrap popover title and content 
 * but move everything into the content (to be able to 'slide' those popovers)
 * we need to take care of several methods ourselves:
 * - grabbing external content from href or data-ref (could be a whitespace separated list) attributes
 * - internal links from href or data-ref (prefixed with '#')
 * - content provided on data-popover-content and data-popover-title attributes (NB: we need to distinguish from the default attributes supported by bootstrap)
 * 
 * Every logical popover is wrapped into a <div class="item"/> within the <div class="popover-content"/>  
 */
function popover_callBack() {
    var urls = [],
        href = $(this).attr('href'),
        dataRefs = $(this).attr('data-ref'),
        popoverID = $(this).attr('aria-describedby'),
        popover = $('#'+popoverID),
        li_templ = $('.carousel-indicators li:last', popover),
        li_clone,
        popover_div,
        popover_data;
    
	/* 
	 * break out of this function if we already created some content 
	 * (and removed the progress bar from the template) 
	 */
    if($('.progress', popover).length === 0) { return }
    
    if(undefined != href) {
        urls.push(href);
    }
    else if(undefined !=  dataRefs) {
        urls = dataRefs.split(/\s+/);
    }
    $(urls).each(function(i,e) {
        popover_div = $('div.item:last', popover);
        popover_div.attr('data-ref', e);
        
        if(e.startsWith('#')) { // local references to endnotes and commentaries
            $('.item-title', popover_div).html($(e).attr('data-title'));
            $('.item-content', popover_div).html($(e).html());
            popover_data = popover.data('bs.popover');
            popover_data.options.content = $('div.popover-content', popover).clone().children();
            popover.popover('show');
        }
        else { // external content via AJAX
            popover_div.preview_popover();
        }
        
		/*
		 * if there are further URLs --> clone the latest div and add the carousel controls 
		 */
        if(urls.length > i +1) {
            popover_div.clone().removeClass('active').insertAfter(popover_div);
            li_clone = li_templ.clone();
            li_clone.attr('data-slide-to', i + 1);
            li_clone.removeClass('active');
            li_clone.insertAfter(li_templ);
        }
    })
    if(urls.length > 1) {
        $('.carousel-indicators, a.carousel-control', popover).show();
        $('.popover-content', popover).addClass('popover-multi');
    }
    
    // content provided via data-popover-content and data-popover-title attributes on the anchor element
    if(undefined != $(this).attr('data-popover-content')) {
        popover_div = $('div.item:last', popover);
        $('.item-title', popover_div).html($(this).attr('data-popover-title'));
        $('.item-content', popover_div).html($(this).attr('data-popover-content'));
        popover_data = popover.data('bs.popover');
        popover_data.options.content = $('div.popover-content', popover).children();
        popover.popover('show');
    }
};

/* checkbox for display of undated documents */
$(document).on('change', '.facet-group input', function() {
    var params = active_facets();
    updatePage(params);
})

/* Start search by clicking on filter button */
$('.searchDocTypeFilter').on('change', 'label', function() {
    /* No need to refresh the page when there's no query string */
    if($('#query-input').val().length) {
        var params = active_facets();
        updatePage(params);
    }
})

$('.glSchemaIDFilter').on('change', 'input', function(a) {
    self.location = '?schemaID=' + a.target.value;
})

$('.obfuscate-email').obfuscateEMail();

$.fn.initPortraitCredits = function() {
    $(this).each( function(_, portrait) {
        /* Hiding the flip back when no image information is available */
        if($('.back p').is(':empty')) { $('.back').hide(); }
        else 
            $(".portrait").flip({
                trigger: 'hover'
            });
    })
};

$(".portrait").initPortraitCredits();


/* Open the first collapsable filter by default */
$('.allFilter .collapse').first().collapse('show');

/* 
 * Toggle line wrap for XML preview 
 */
function init_line_wrap_toggle() {
    var pre = $('.line-wrap-toggle ~ pre'),
        input = $('.line-wrap-toggle input'),
        url = $('.allFilter .nav-tabs .loaded').attr('data-tab-url');
    
    // set toggle on load 
    if(pre.hasClass('line-wrap')) {
        input.bootstrapToggle('on');
    }
    else {
        input.bootstrapToggle('off');
    }
    
    // set listener for toggle
    input.change(
        function(a,b) {
            pre.toggleClass('line-wrap');
            // update session
            $.get(url + '?line-wrap=' + pre.hasClass('line-wrap'));
        }
    )
};

/* 
 * Helper function
 * Get active facets to append as URL parameters 
 */
function active_facets() {
    var params = {
            facets:[],
            fromDate:'',
            toDate:'',
            toString:function(){
                if(this.fromDate !== '') {
                    this.facets.push('fromDate=' + this.fromDate);
                };
                if(this.toDate !== '') {
                    this.facets.push('toDate=' + this.toDate);
                };
                return '?' + this.facets.join('&')
            }
        },
        slider, from, to, min, max;
     
    /* Pushing the limit parameter to the facets array */
    params['facets'].push('limit='+$('.switch-limit .active a:first').text());
     
    /* Set filters from the side menu */
    $('.allFilter:visible :selected').each(function() {
        var facet = $(this).parent().attr('name'),
            value = $(this).attr('value');
        /*console.log(facet + '=' + value);*/
        params['facets'].push(facet + '=' + encodeURI(value))
    })
    /* Get date values from range slider */
    if($('.rangeSlider:visible').length) {
        slider = $('.rangeSlider:visible');
        from=slider.attr('data-from-slider');
        to=slider.attr('data-to-slider');
        min=slider.attr('data-min-slider');
        max=slider.attr('data-max-slider');
        params['fromDate'] = (from > min)? from: '';
        params['toDate'] = (to < max)? to: '';
    }
    /* get values from checkboxes for docTypes at search page 
     * as well as for other checkboxes on list pages like 'revealed' or 'undated'
     */
    $('.allFilter:visible :checked').each(function() {
        var facet = $(this).attr('name'),
            value = $(this).attr('value')? $(this).attr('value'): 'true';
        if(undefined != facet) { params['facets'].push(facet + '=' + encodeURI(value)) }
    })
    if($('#query-input').val()) {
        params['facets'].push('q=' + $('#query-input').val());
    }
    else if($('#query-string').length) {
        params['facets'].push('q=' + $('#query-string').text());
    }
    return params;
}

/* Helper function */
/* See whether we're in a person context and need to update via AJAX
 * or on an index page and need to refresh the whole page
 */
function updatePage(params) {
    /* AJAX call for personal writings etc. */
    if($('li.resp-tab-active').length === 1) {
        var url = $('li.resp-tab-active a').attr('data-target') + params.toString(),
            container = $('li.resp-tab-active a').attr('href');
        ajaxCall(container, url)
    }
    /* Refresh page for indices */
    else {
        self.location = params.toString();
    }
}

/* activate tooltips for jubilees on start page 
 * as well as for Julian dates on person pages
 */
$('.jubilee, .jul').tooltip();

/* Initialise selectize plugin for facets on index pages */
$('.allFilter select').facets();

/* Initialise range slider for index pages */
$('.allFilter:visible .rangeSlider').rangeSlider();


$('h1').h1FitText();

/* hide tabs with no respective div content */
$('li').has('a.deactivated').hide();

/* 
 * Initialise easyResponsiveTabs for person.html 
 */
$('#details').easyResponsiveTabs({
    activate: activateTab
});

/* Folgender Aufruf *nach* der Initialisierung durch easyResponsiveTabs() */
$('.resp-tab-item a').toggleTab();

/* Activate greedy nav on person pages */
$('.greedy').greedyNav();

/* Watch filters and highlight spans in text */
$('.allFilter input').change(
  function() {
    var key = $(this).attr('value');
    $('.' + key).toggleClass('hi-' + key);
  }
)

/* Highlight original (historic) footnotes when clicking on a reference in the text */
$('.fn-ref').on('click', function() {
    $('#endNotes li').removeClass('bg-info');
    $($(this).attr('href')).addClass('bg-info');
})

function ajaxCall(container,url,callback) {
    $(container).mask();
    $(container).load(url, function(response, status, xhr) {
        if ( status == "error" ) {
            console.log(xhr.status + ": " + xhr.statusText);
        }
        else {
            /* update facets */
            $('.allFilter:visible select').facets();
            $('.allFilter:visible .rangeSlider').rangeSlider();
            /* Listen for click events on pagination */
            $('.page-link:visible').on('click', 
                function() {
                    $(this).activatePagination(container);
                }
            );
            
            /* 
             * Not very generic but at present only needed for backlinks,
             * see removeFilter()
             */
            if(typeof callback === 'function') {
                callback($(container).children(), '', container);
            }
            
            /* Load portraits via AJAX */
            $('.searchResults .portrait').loadPortrait();
            $("#datePicker").initDatepicker();
        }
    });
};
        
$.fn.activatePagination = function(container) {
    /*  Two possible locations:  */
    var activeTab = $('li.resp-tab-active a, ul.nav-tabs li.active a'),
    /*  with different attributes */
        baseUrl = activeTab.attr('data-target')? activeTab.attr('data-target'): activeTab.attr('data-tab-url'),
        url = baseUrl + $(this).attr('data-url'),
        callback;
    
    /* 
     * the data-tab-callback attribute may contain the name of a callback function
     * this is provided by the nav-tabs remote data plugin 
     * and we use it to remove filters from the backlinks AJAX page
     */
    if($('.nav-tabs .active a[data-tab-callback]').length === 1) {
        callback = window[$('.nav-tabs .active a').attr('data-tab-callback')];
    }    
    
    ajaxCall(container,url,callback);
    return this
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

$("#datePicker").initDatepicker();

/* Fieser Hack */
$('#facsimile-tab').on('click', function() {
    setTimeout(function() {
       if ($('#map:visible')){
           initFacsimile();
       }
   }, 500);
});

/* Load portraits via AJAX on index pages */
$('.searchResults .portrait').loadPortrait();

/* Put focus on text inputs */
$('#query-input').focus();

/* Umbruch der Teaserüberschriften abhängig von Textlänge */
$('.teaser + h2 a').each(function(a,b) {
    var string = $(b).text().trim(),
        tokens = string.split(' '),
        i = 0,
        newText = '',
        str = '';
    while (i < string.length / 3 ) {
        str = tokens.shift();
        newText += str + " ";
        i+=str.length;
    }
    newText += '<br/>'
    newText += tokens.join(' ');
    $(b).html(newText);
})

$('.preview').setTextWrap();

function initFacsimile() {
    var map,
        iiifLayers = {}
        manifestUrl = $('#map').attr('data-url');
    
    map = L.map('map', {
        center: [0, 0],
        crs: L.CRS.Simple,
        zoom: 0,
        attributionControl: false
    });
    
    

    // Grab a IIIF manifest
    $.getJSON(manifestUrl, function(data) {
      // For each image create a L.TileLayer.Iiif object and add that to an object literal for the layer control
      $.each(data.sequences[0].canvases, function(_, val) {
        iiifLayers[val.label] = L.tileLayer.iiif(val.images[0].resource.service['@id'] + '/info.json');
      });
        // Add layers control to the map
        L.control.layers(iiifLayers).addTo(map);
        
        // Access the first Iiif object and add it to the map
        iiifLayers[Object.keys(iiifLayers)[0]].addTo(map);
    });
};

function jump2diary(dateText) {
    var url = $('#datePicker').attr('data-api-base') + "/documents/findByDate?docType=diaries&limit=1&fromDate=" + dateText + "&toDate=" + dateText ;
    $.getJSON(url, function(data) {
        self.location=data.uri + '.html';
    })
};

/* Exclude diary days from datePicker */
/* (some days are missing from Weber's diaries) */
function checkValidDiaryDate(date) {
    /* 5-20 April 1814 */
    /* 26-31. Mai 1814 */
    /* 1-9 Juni 1814 */
    /* 19-30 Juni 1814 */
    /* 1-26 Juli 1814 */
    /* August – Dezember 1814 */
    /* 9-16 April 1819 */
    /* 18–21 April 1819 */
    /* 23 April 1819 */
    /* 26–27 April 1819 */
    /* 29 April 1819 */
    /* 3-4 Mai 1819 */
    /* 9-11 Mai 1819*/
   
    var start1 =  new Date('04/05/1814'),
		 end1 =  new Date('04/20/1814'),
		 start2 =  new Date('05/26/1814'),
		 end2 =  new Date('05/31/1814'),
		 start3 =  new Date('06/01/1814'),
		 end3 =  new Date('06/09/1814'),
		 start4 =  new Date('06/19/1814'),
		 end4 =  new Date('06/30/1814'),
		 start5 =  new Date('07/01/1814'),
		 end5 =  new Date('07/26/1814'),
		 start6 =  new Date('08/01/1814'),
		 end6 =  new Date('12/31/1814'),
		 start7 =  new Date('04/09/1819'),
		 end7 =  new Date('04/16/1819'),
		 start8 =  new Date('04/18/1819'),
		 end8 =  new Date('04/21/1819'),
		 day9 =  new Date('04/23/1819'),
		 start10 =  new Date('04/26/1819'),
		 end10 =  new Date('04/27/1819'),
		 day11 =  new Date('04/29/1819'),
		 start12 =  new Date('05/03/1819'),
		 end12 =  new Date('05/04/1819'),
		 start13 =  new Date('05/09/1819'),
		 end13 =  new Date('05/11/1819');
    return !(
        (date >= start1 && date <= end1) ||
        (date >= start2 && date <= end2) ||
        (date >= start3 && date <= end3) ||
        (date >= start4 && date <= end4) ||
        (date >= start5 && date <= end5) ||
        (date >= start6 && date <= end6) ||
        (date >= start7 && date <= end7) ||
        (date >= start8 && date <= end8) ||
        (date >= day9 && date <= day9) ||
        (date >= start10 && date <= end10) ||
        (date >= day11 && date <= day11) ||
        (date >= start12 && date <= end12) ||
        (date >= start13 && date <= end13)
    )
};

/* Get the current language from the top navigation */
function getLanguage() {
    return $('#navbarCollapse li.active:last a').html().toLowerCase()
};

/* Get the current diary date from the h1 heading */
function getDiaryDate() {
    /* Datumsangabe auf Listenseite (h3) oder auf Einzelansicht (h1) */
    var title = ($('h1.document').length === 0)? $('h3.media-heading a').html().replace(/<br.+/, '') : $('h1.document').html().replace(/<br.+/, '') ,
		 lang = getLanguage(),
		 format,
		 date = '';
    if(lang === 'de') { 
        format = "DD, dd. MM yy" 
    } 
    else { 
        format = "DD, MM dd, yy" 
    } ; 
    
    try { 
        date = 
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
    return $('.breadcrumb li:last').text().trim()
};

/* Add search option for advanced search */
function addSearchOption(that)
{
    $(that).closest(".col-md-9").append("<div class='searchform'>"+$(that).closest(".searchform").html()+"</div>");
}

/* Development only: request a new ID */
$('#create-newID').on('click', function() {
    $('#newID-result span').hide();
    $('#newID-result i').show();
    var docType = $('#newID-select :selected').val();
    $.getJSON('../dev/api.xql?func=get-new-id&format=json&docType='+docType, function(response) {
        $('#newID-result span').html(response);
        $('#newID-result i').hide();
        $('#newID-result span').show();
    });
});

