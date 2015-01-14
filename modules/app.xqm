xquery version "3.0" encoding "UTF-8";

module namespace app="http://xquery.weber-gesamtausgabe.de/modules/app";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mei="http://www.music-encoding.org/ns/mei";
declare namespace templates="http://exist-db.org/xquery/templates";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xhtml="http://www.w3.org/1999/xhtml";
declare namespace gndo="http://d-nb.info/standards/elementset/gnd#";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
(:declare namespace request = "http://exist-db.org/xquery/request";:)
declare namespace session = "http://exist-db.org/xquery/session";

import module namespace core="http://xquery.weber-gesamtausgabe.de/modules/core" at "core.xqm";
import module namespace config="http://xquery.weber-gesamtausgabe.de/modules/config" at "config.xqm";
import module namespace query="http://xquery.weber-gesamtausgabe.de/modules/query" at "query.xqm";
import module namespace date="http://xquery.weber-gesamtausgabe.de/modules/date" at "date.xqm";
import module namespace lang="http://xquery.weber-gesamtausgabe.de/modules/lang" at "lang.xqm";
import module namespace str="http://xquery.weber-gesamtausgabe.de/modules/str" at "str.xqm";
import module namespace controller="http://xquery.weber-gesamtausgabe.de/modules/controller" at "controller.xqm";
import module namespace js="http://xquery.weber-gesamtausgabe.de/modules/js" at "js.xqm";
import module namespace wega-util="http://xquery.weber-gesamtausgabe.de/modules/wega-util" at "wega-util.xqm";
import module namespace functx="http://www.functx.com";
import module namespace datetime="http://exist-db.org/xquery/datetime" at "java:org.exist.xquery.modules.datetime.DateTimeModule";

declare function app:page-title($node as node(), $model as map(*)) as element(title) {
    <title>{$model('page-title')}</title>
};

(:
 : ****************************
 : Generic functions
 : ****************************
:)

(:~
 : Creates link to doc
 :
 : @author Peter Stadler
 : @param $doc document node
 : @param $lang the current language (de|en)
 : @return xs:string
:)
declare function app:createUrlForDoc($doc as document-node(), $lang as xs:string) as xs:string? {
    let $path :=  controller:path-to-resource($doc, $lang)
    return
        if($path) then core:link-to-current-app($path || '.html')
        else ()
};

(:~
 : Creates an xhtml:a link to a WeGA document
 :
 : @author Peter Stadler
 : @param $doc the document to create the link for
 : @param $content the string content for the xhtml a element
 : @param $lang the language switch (en, de)
 : @param $attributes a sequence of attribute-value-pairs, e.g. ('class=xy', 'style=display:block')
 :)
declare function app:createDocLink($doc as document-node(), $content as xs:string, $lang as xs:string, $attributes as xs:string*) as element() {
    let $href := app:createUrlForDoc($doc, $lang)
    let $docID :=  $doc/root()/*/@xml:id
    return 
    element a {
        attribute href {$href},
        if(exists($attributes)) then for $att in $attributes return attribute {substring-before($att, '=')} {substring-after($att, '=')} 
        else (),
        $content
    }
};

(:~
 : Set an attribute to the value given in the $model map
 :
 : @author Peter Stadler
 :)
declare function app:set-attr($node as node(), $model as map(*), $attr as xs:string, $key as xs:string) as element() {
    element {name($node)} {
        $node/@*[not(name(.) = $attr)],
        attribute {$attr} {$model($key)},
        templates:process($node/node(), $model)
    }
};

(:~
 : Simply print a value from the $model map
 :
 : @author Peter Stadler
 :)
declare 
    %templates:wrap
    function app:print($node as node(), $model as map(*), $key as xs:string) as xs:string? {
        if ($model($key) castable as xs:string) then string($model($key))
        else ()
};

(:~
 : Add additional JavaScript to the page template
 : which gets invoked at the end of the page
 :
 : @author Peter Stadler
 :)
declare function app:page-javascript($node as node(), $model as map(*)) as element(script)* {
    js:obfuscate-email(),
    js:load-portrait($model)
};

declare 
    %templates:default("lang", "en")
    %templates:wrap
    function app:print-bugReportEmail($node as node(), $model as map(*), $lang as xs:string) as element(p) {
        if($lang eq 'de') then 
            <p>Wenn Ihnen auf dieser Seite ein Fehler oder eine Ungenauigkeit aufgefallen ist, so bitten wir um eine kurze Nachricht an
                <a href="#" class="obfuscate-email">You need Javascript enabled</a>
            </p>
        else 
            <p>If you've spotted some error or inaccurateness please do not hesitate to inform us via 
                <a href="#" class="obfuscate-email">You need Javascript enabled</a>
            </p>
};

declare
    %templates:default("lang", "en")
    %templates:wrap
    function app:print-permaLink($node as node(), $model as map(*), $lang as xs:string) as element(p) {
        let $dateFormat := if($lang eq 'en')
            then '%B %d, %Y'
            else '%d. %B %Y'
        let $svnProps := config:get-svn-props($model('docID'))
        let $author := map:get($svnProps, 'author')
        let $date := xs:dateTime(map:get($svnProps, 'dateTime'))
        let $version := concat(config:get-option('version'), if($config:isDevelopment) then 'dev' else '')
        let $versionDate := date:strfdate(xs:date(config:get-option('versionDate')), $lang, $dateFormat)
        let $permalink := core:permalink($model('docID'))
        return 
            <p>{lang:get-language-string('proposedCitation', $lang)}, {$permalink} ({app:createDocLink(core:doc(config:get-option('versionNews')), lang:get-language-string('versionInformation',($version, $versionDate), $lang), $lang, ())})
                <br/>
                {if($config:isDevelopment) then lang:get-language-string('lastChangeDateWithAuthor',(date:strfdate($date, $lang, $dateFormat),$author),$lang)
                else lang:get-language-string('lastChangeDateWithoutAuthor', date:strfdate($date, $lang, $dateFormat), $lang)
                }
            </p>
};

(:~
 : A non-wrapping alternative to the standard templates:each()
 : Gets rid of the superfluous first list item
 :
 : @author Peter Stadler
 :)
declare function app:each($node as node(), $model as map(*), $from as xs:string, $to as xs:string) {
    for $item in $model($from)
    return
        element { node-name($node) } {
            $node/@*, templates:process($node/node(), map:new(($model, map:entry($to, $item))))
        }
};


(:
 : ****************************
 : Breadcrumbs 
 : ****************************
:)
declare 
    %templates:default("lang", "en")
    function app:breadcrumb-person($node as node(), $model as map(*), $lang as xs:string) as element(a) {
        let $authorID := 
            if(config:is-person($model('docID'))) then $model('docID')
            else query:get-authorID($model('doc'))
        let $href := app:createUrlForDoc(core:doc($authorID), $lang)
        return 
            element {node-name($node)} {
                $node/@*[not(local-name(.) eq 'href')],
                if($href) then attribute href {$href} else (),
                str:printFornameSurname(query:get-reg-name($authorID))
            }
};

declare
    %templates:default("lang", "en")
    function app:breadcrumb-docType($node as node(), $model as map(*), $lang as xs:string) as element(a) {
        let $authorID := query:get-authorID($model('doc'))
        let $href := functx:substring-before-last(controller:path-to-resource($model('doc'), $lang), '/')
        let $display-name := functx:substring-after-last($href, '/')
        return
            element {node-name($node)} {
                $node/@*[not(local-name(.) eq 'href')],
                if($href) then attribute href {$href} else (),
                $display-name
            }
};


(:
 : ****************************
 : Navigation / Tabs 
 : ****************************
:)

declare
    %templates:default("lang", "en")
    function app:person-main-tab($node as node(), $model as map(*), $lang as xs:string) as element()? {
        let $tabTitle := normalize-space($node)
        let $count := count($model($tabTitle))
        let $alwaysShowNoCount := $tabTitle = 'biographies'
        return
            if($count gt 0 or $alwaysShowNoCount) then
                element {name($node)} {
                        $node/@*,
                        lang:get-language-string($tabTitle, $lang),
                        if($alwaysShowNoCount) then () else ' (' || $count || ')'
                    }
            else 
                element {name($node)} {
                    attribute class {'deactivated'}
                }
};

declare
    %templates:default("lang", "en")
    function app:ajax-tab($node as node(), $model as map(*), $lang as xs:string) as element() {
        let $beacon := 
            try {map:keys($model('beaconMap'))}
            catch * {()}
        let $ajax-url :=
            switch(normalize-space($node))
            case 'XML-Preview' return 'xml.html'
            case 'wikipedia-article' return if($beacon = 'Wikipedia-Personenartikel') then 'wikipedia.html' else ()
            case 'adb-article' return if($beacon = 'Allgemeine Deutsche Biographie (Wikisource)') then 'adb.html' else ()
            case 'dnb-entry' return if($model('gnd')) then 'dnb.html' else ()
            default return ()
        return
            if($ajax-url) then 
                element {name($node)} {
                    $node/@*,
                    attribute data-tab-url {core:link-to-current-app(controller:path-to-resource($model('doc'), $lang) || '/' || $ajax-url)},
                    lang:get-language-string(normalize-space($node), $lang)
                }
            else
                element {name($node)} {
                    attribute class {'deactivated'}
                }
};

declare
    %templates:default("lang", "en")
    function app:tab($node as node(), $model as map(*), $lang as xs:string) as element() {
        (: Currently only needed for "PND Beacon Links" :)
        if($model('gnd')) then
            element {name($node)} {
                $node/@*,
                normalize-space($node)
            }
        else
            element {name($node)} {
                attribute class {'deactivated'}
            }
};


(:
 : ****************************
 : Index page
 : ****************************
:)

declare 
    %templates:wrap
    %templates:default("lang", "en")
    function app:word-of-the-day($node as node(), $model as map(*), $lang as xs:string) as map(*) {
        let $words := core:getOrCreateColl('letters', 'A002068', true())//tei:seg[@type='wordOfTheDay']
        let $random := util:random(count($words) - 1) + 1 (: util:random may return 0! :)
(:        let $log := util:log-system-out($words[$random]/ancestor::tei:TEI/string(@xml:id)):)
        return 
            map {
                'wordOfTheDay' := str:enquote(str:normalize-space($words[$random]), $lang),
                'wordOfTheDayURL' := app:createUrlForDoc(core:doc($words[$random]/ancestor::tei:TEI/string(@xml:id)), $lang)
            }
};

declare 
    %templates:wrap
    function app:lookup-todays-events($node as node(), $model as map(*)) as map(*) {
    let $events := 
        for $i in query:getTodaysEvents(current-date())
        order by $i/xs:date(@when) ascending
        return $i
    let $length := count($events)
    return
        map {
            'events1' := subsequence($events, 1, ceiling($length div 2)),
            'events2' := subsequence($events, ceiling($length div 2) + 1)
        }
};

declare function app:print-event($node as node(), $model as map(*), $lang as xs:string) as element(span) {
    let $date := current-date()
    let $teiDate := $model('event')
    let $isJubilee := (year-from-date($date) - $teiDate/year-from-date(@when)) mod 25 = 0
    let $typeOfEvent := 
        if($teiDate/ancestor::tei:correspDesc) then 'letter'
        else if($teiDate[@type='baptism']) then 'isBaptised'
        else if($teiDate/parent::tei:birth) then 'isBorn'
        else if($teiDate[@type='funeral']) then 'wasBuried'
        else if($teiDate/parent::tei:death) then 'dies'
        else ()
    return
        element span {
                if($isJubilee) then (
                    attribute class {'jubilee'},
                    attribute title {lang:get-language-string('roundYearsAgo',xs:string(year-from-date($date) - $teiDate/year-from-date(@when)), $lang)}
                )
                else (),
                concat(date:formatYear($teiDate/year-from-date(@when) cast as xs:int, $lang), ': '),
                if($typeOfEvent eq 'letter') then app:createLetterLink($teiDate, $lang)
                (:else (wega:createPersonLink($teiDate/root()/*/string(@xml:id), $lang, 'fs'), ' ', lang:get-language-string($typeOfEvent, $lang)):)
                else (app:createDocLink($teiDate/root(), str:printFornameSurname(query:get-reg-name($teiDate/ancestor::tei:person/@xml:id)), $lang, ()), ' ', lang:get-language-string($typeOfEvent, $lang))
            }
};

declare function app:print-events-title($node as node(), $model as map(*), $lang as xs:string) as element(h2) {
    <h2>{lang:get-language-string('whatHappenedOn', date:strfdate(current-date(), $lang, if($lang eq 'en') then '%B %d' else '%d. %B'), $lang)}</h2>
};

(:~
 : Helper function for app:print-event
 :
 : @author Peter Stadler
 :)
declare %private function app:createLetterLink($teiDate as element(tei:date)?, $lang as xs:string) as item()* {
    let $sender := app:printCorrespondentName($teiDate/ancestor::tei:correspDesc/tei:sender[1]/*[1], $lang, 'fs')
    let $addressee := app:printCorrespondentName($teiDate/ancestor::tei:correspDesc/tei:addressee[1]/*[1], $lang, 'fs')
    return (
        $sender, ' ', lang:get-language-string('writesTo', $lang), ' ', $addressee, 
        if(ends-with($addressee, '.')) then ' ' else '. ', 
        app:createDocLink($teiDate/root(), concat('[', lang:get-language-string('readOnLetter', $lang), ']'), $lang, ('class=readOn'))
    )
};

(:~
 : Construct a name from a tei:persName or tei:name element wrapped in a <span> 
 : If a @key is given on persName the regularized form will be returned, otherwise the content of persName.
 : If persName is empty than "unknown" is returned.
 : 
 : @author Peter Stadler
 : @param $persName the tei:persName element
 : @param $lang the current language (de|en)
 : @param $order (sf|fs) whether to print "surname, forename" or "forename surname"
 : @return 
 :)
declare function app:printCorrespondentName($persName as element()?, $lang as xs:string, $order as xs:string) as element() {
     if(exists($persName/@key)) then app:createDocLink(core:doc($persName/string(@key)), str:printFornameSurname(query:get-reg-name($persName/@key)), $lang, ())
        (:wega:createPersonLink($persName/string(@key), $lang, $order):)
     else if ($order eq 'fs') then <xhtml:span class="noDataFound">{str:printFornameSurname($persName)}</xhtml:span>
     else if (not(functx:all-whitespace($persName))) then <xhtml:span class="noDataFound">{string($persName)}</xhtml:span>
     else <xhtml:span class="noDataFound">{lang:get-language-string('unknown',$lang)}</xhtml:span>
};


(:
 : ****************************
 : Person pages
 : ****************************
:)

declare 
    %templates:wrap
    function app:person-title($node as node(), $model as map(*)) as xs:string {
        query:get-reg-name($model('docID'))
};

declare 
    %templates:wrap
    %templates:default("lang", "en")
    function app:basic-data($node as node(), $model as map(*), $lang as xs:string) as map(*) {
        map{
            'fullnames' := $model('doc')//tei:persName[@type = 'full'],
            'pseudonyme' := $model('doc')//tei:persName[@type = 'pseud'],
            'birthnames' := $model('doc')//tei:persName[@subtype = 'birth'],
            'realnames' := $model('doc')//tei:persName[@type = 'real'],
            'marriednames' := $model('doc')//tei:persName[@subtype = 'married'],
            'births' := date:printDate($model('doc')//tei:birth/tei:date[1], $lang),
            'deaths' := date:printDate($model('doc')//tei:death/tei:date[1], $lang)
        }
};

declare 
    %templates:wrap
    function app:person-details($node as node(), $model as map(*)) as map(*) {
        let $gnd := query:get-gnd($model('doc'))
        (:let $docTypes-for-display := ('letters', 'diaries', 'writings', 'works')
        let $docTypes := map:new(
            for $docType in $docTypes-for-display
            return 
                map:entry($docType, core:getOrCreateColl($docType, $model('docID'), true()))
        ):)
(:        let $contacts := distinct-values(core:getOrCreateColl('letters', $model('docID'), true())//@key[ancestor::tei:correspDesc][. != $model('docID')]):)
        
(:        let $backlinks := core:getOrCreateColl('letters', 'indices', true())//@key[.=$model('docID')] | core:getOrCreateColl('diaries', 'indices', true())//@key[.=$model('docID')] | core:getOrCreateColl('writings', 'indices', true())//@key[.=$model('docID')] | core:getOrCreateColl('persons', 'indices', true())//@key[.=$model('docID')]:)
        
        let $beaconMap := 
            if($gnd) then wega-util:beacon-map($gnd)
            else map:new()
        
        return
            map{
(:                'docTypesMap' := $docTypes,:)
                'correspondence' := core:getOrCreateColl('letters', $model('docID'), true()),
                'diaries' := core:getOrCreateColl('diaries', $model('docID'), true()),
                'writings' := core:getOrCreateColl('writings', $model('docID'), true()),
                'works' := core:getOrCreateColl('works', $model('docID'), true()),
                'contacts' := distinct-values(core:getOrCreateColl('letters', $model('docID'), true())//@key[ancestor::tei:correspDesc][. != $model('docID')]),
                'backlinks' := core:getOrCreateColl('letters', 'indices', true())//@key[.=$model('docID')] | core:getOrCreateColl('diaries', 'indices', true())//@key[.=$model('docID')] | core:getOrCreateColl('writings', 'indices', true())//@key[.=$model('docID')] | core:getOrCreateColl('persons', 'indices', true())//@key[.=$model('docID')],
                'gnd' := $gnd,
                'beaconMap' := $beaconMap
(:                'xml-download-URL' := core:link-to-current-app($model('docID') || '.xml'):)
            }
};

(:declare
    %templates:wrap
    %templates:default("lang", "en")
    function app:docType-tabs($node as node(), $model as map(*), $lang as xs:string) as map(*) {
        let $documents := map { 
            'title' := lang:get-language-string('biographies', $lang),
            'target' := 'biographies',
            'count' := (\:count(for $i in app:document-tabs($node, $model, $lang)('document-tabs') where not($i('title') = ('XML-Preview', 'PND Beacon Links'))  return $i):\) '1'
        }
        let $docTypes := 
            for $docType in map:keys($model('docTypesMap')) 
            where count($model('docTypesMap')($docType)) gt 0
            return
                map {
                    'title' := lang:get-language-string($docType, $lang),
                    'target' := $docType,
                    'count' := count($model('docTypesMap')($docType))
                }
        let $contacts := 
            if(count($model('contacts')) gt 0) then 
                map {
                    'title' := lang:get-language-string('contacts', $lang),
                    'target' := 'contacts',
                    'count' := count($model('contacts'))
                }
            else ()
        let $backlinks := 
            if(count($model('backlinks')) gt 0) then 
                map {
                    'title' := lang:get-language-string('backlinks', $lang),
                    'target' := 'contacts',
                    'count' := count($model('backlinks'))
                }
            else ()
        
        return 
            map {
                'docType-tabs' := (
                    $documents,
                    $docTypes,
                    $contacts,
                    $backlinks
                )
            }
};:)

(:declare
    %templates:default("lang", "en")
    function app:print-docType-tab($node as node(), $model as map(*), $lang as xs:string) as element() {
        element {node-name($node)} {
            $node/@*[not(local-name(.) eq 'target')],
            attribute target {'.' || $model('docType-tab')('target')},
            $model('docType-tab')('title') || ' (' || $model('docType-tab')('count') || ')'
        }
};:)

declare 
    %templates:default("lang", "en")
    function app:print-wega-bio($node as node(), $model as map(*), $lang as xs:string) as element(div)? {
        transform:transform($model('doc')//tei:note[@type="bioSummary"], doc(concat($config:xsl-collection-path, '/person_singleView.xsl')), config:get-xsl-params(()))
};

declare function app:print-beacon-links($node as node(), $model as map(*)) as element(ul) {
        let $beaconMap := $model('beaconMap')
        return
            <ul>{
                for $i in map:keys($beaconMap)
                return 
                    <li><a title="{$i}" href="{$beaconMap($i)[1]}">{$beaconMap($i)[2]}</a></li>
            }</ul>
};

(:~
 : Main Function for wikipedia.html
 : Creates the wikipedia model
 :
 : @author Peter Stadler 
 : @return map with keys:('wikiContent','wikiUrl','wikiName')
 :)
declare 
    %templates:wrap
    %templates:default("lang", "en")
    function app:wikipedia($node as node(), $model as map(*), $lang as xs:string) as map(*) {
        let $gnd := query:get-gnd($model('doc'))
        let $wikiContent := wega-util:grabExternalResource('wikipedia', $gnd, $lang)
        let $wikiUrl := $wikiContent//xhtml:div[@class eq 'printfooter']/xhtml:a[1]/data(@href)
        let $wikiName := normalize-space($wikiContent//xhtml:h1[@id = 'firstHeading'])
        return 
            map {
                'wikiContent' := $wikiContent,
                'wikiUrl' := $wikiUrl,
                'wikiName' := $wikiName
            }
};


declare function app:wikipedia-text($node as node(), $model as map(*)) as element() {
    element {name($node)} {
        $node/@*,
        transform:transform($model('wikiContent')//xhtml:div[@id='bodyContent'], doc(concat($config:xsl-collection-path, '/person_wikipedia.xsl')), config:get-xsl-params(()))/node()
    }
};

declare 
    %templates:default("lang", "en")
    function app:wikipedia-disclaimer($node as node(), $model as map(*), $lang as xs:string) as element() {
    element {name($node)} {
        $node/@*,
        
        if($lang eq 'en') then (
            'The content of this "Wikipedia" entitled box is taken from the article "',
            <a href='{$model('wikiUrl')}' title='Wikipedia article for {$model('wikiName')}'>{$model('wikiName')}</a>,
            '" from ',
            <a href="http://en.wikipedia.org">Wikipedia</a>,
            'the free encyclopedia, and is released under a ',
            <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">CC-BY-SA-license</a>,
            '. You will find the ',
            <a href="{concat(replace($model('wikiUrl'), 'wiki/', 'w/index.php?title='), '&amp;action=history')}" title="Authors and revision history of the Wikipedia Article for {$model('wikiName')}">revision history along with the authors</a>,
            'of this article in Wikipedia.'
        )
            
        else (
            'Der Inhalt dieser mit "Wikipedia" bezeichneten Box entstammt dem Artikel "',
            <a href='{$model('wikiUrl')}' title='Wikipedia Artikel zu "{$model('wikiName')}"'>{$model('wikiName')}</a>,
            '" aus der freien Enzyklopädie ',
            <a href="http://de.wikipedia.org" title="Wikipedia Hauptseite">Wikipedia</a>, 
            ' und steht unter der ',
            <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.de">CC-BY-SA-Lizenz</a>,
            '. In der Wikipedia findet sich auch die ',
            <a href="{concat(replace($model('wikiUrl'), 'wiki/', 'w/index.php?title='), '&amp;action=history')}" title='Autoren und Versionsgeschichte des Wikipedia Artikels zu "{$model('wikiName')}"'>Versionsgeschichte mitsamt Autorennamen</a>,
            ' für diesen Artikel.'
        )
    }
};

(:~
 : Main Function for adb.html
 : Creates the ADB model
 :
 : @author Peter Stadler 
 : @return map with key:'adbContent'
 :)
declare 
    %templates:wrap
    %templates:default("lang", "en")
    function app:adb($node as node(), $model as map(*), $lang as xs:string) as map(*) {
        map {
            'adbContent' := wega-util:grabExternalResource('adb', query:get-gnd($model('doc')), ())
        }
};


declare function app:adb-text($node as node(), $model as map(*)) as element() {
    element {name($node)} {
        $node/@*,
        transform:transform($model('adbContent')//xhtml:div[@id='bodyContent'], doc(concat($config:xsl-collection-path, '/person_wikipedia.xsl')), config:get-xsl-params(()))/node()
    }
};

declare function app:adb-disclaimer($node as node(), $model as map(*)) as element() {
    element {name($node)} {
        $node/@*,
        transform:transform($model('adbContent')//xhtml:div[@id='adbcite'], doc(concat($config:xsl-collection-path, '/person_wikipedia.xsl')), config:get-xsl-params(map {'mode' := 'appendix'}))
    }
};

declare 
    %templates:wrap
    %templates:default("lang", "en")
    function app:dnb($node as node(), $model as map(*), $lang as xs:string) as map(*) {
        let $dnbContent := wega-util:grabExternalResource('dnb', query:get-gnd($model('doc')), ())
(:        let $log := util:log-system-out($dnbContent//rdf:Description/gndo:preferredNameForThePerson/string()):)
        return
            map {
                'dnbContent' := $dnbContent,
                'dnbName' := $dnbContent//rdf:RDF/rdf:Description/gndo:preferredNameForThePerson/string(),
                'dnbBirths' := if($dnbContent//gndo:dateOfBirth castable as xs:date) then date:getNiceDate($dnbContent//gndo:dateOfBirth, $lang) else(),
                'dnbDeaths' := if($dnbContent//gndo:dateOfDeath castable as xs:date) then date:getNiceDate($dnbContent//gndo:dateOfDeath, $lang) else(),
                'dnbOccupations' := $dnbContent//rdf:RDF/rdf:Description/gndo:professionOrOccupation/string(),
                'dnbOtherNames' := $dnbContent//rdf:RDF/rdf:Description/gndo:variantNameForThePerson/string()
            }
};

declare function app:xml-prettify($node as node(), $model as map(*)) {
        let $docID := $model('docID')
        let $serializationParameters := ('method=xml', 'media-type=application/xml', 'indent=no', 'omit-xml-declaration=yes', 'encoding=utf-8')
        return
            if($config:isDevelopment) then util:serialize(core:doc($docID), $serializationParameters)
            else util:serialize(wega-util:remove-comments(core:doc($docID)), $serializationParameters)
};


(:
 : ****************************
 : Document pages
 : ****************************
:)
declare
    %templates:wrap
    %templates:default("lang", "en")
    function app:document-title($node as node(), $model as map(*), $lang as xs:string) {
        let $title-element := query:get-title-element($model('doc'))[1]
        return
            typeswitch($title-element)
            case element(tei:title) return transform:transform($title-element, doc(concat($config:xsl-collection-path, '/common_main.xsl')), config:get-xsl-params(()))/node()
            case element(mei:title) return error(xs:QName('app:error'), 'function not yet implemented')
            default return transform:transform(app:construct-title($model('doc'), $lang), doc(concat($config:xsl-collection-path, '/common_main.xsl')), config:get-xsl-params(()))/node()
            
};

declare 
    %templates:wrap
    %templates:default("lang", "en")
    function app:print-transcription($node as node(), $model as map(*), $lang as xs:string) {
        let $doc := $model('doc')
        let $docID := $model('docID')
        let $xslParams := config:get-xsl-params( map {
            'dbPath' := document-uri($doc),
            'docID' := $docID,
            'transcript' := 'true'
            } )
        let $xslt := 
            if(config:is-letter($docID)) then doc(concat($config:xsl-collection-path, '/letter_text.xsl'))
            else if(config:is-news($docID)) then doc(concat($config:xsl-collection-path, '/news.xsl'))
            else if(config:is-writing($docID)) then doc(concat($config:xsl-collection-path, '/doc_text.xsl'))
            else ()
    let $body := 
         if(functx:all-whitespace($doc//tei:text))
         then (
            let $summary := if(functx:all-whitespace($doc//tei:note[@type='summary'])) then () else transform:transform($doc//tei:note[@type='summary'], doc(concat($config:xsl-collection-path, '/letter_text.xsl')), $xslParams) 
            let $incipit := if(functx:all-whitespace($doc//tei:incipit)) then () else transform:transform($doc//tei:incipit, doc(concat($config:xsl-collection-path, '/letter_text.xsl')), $xslParams)
            let $text := if($doc//tei:correspDesc[@n = 'revealed']) then lang:get-language-string('correspondenceTextNotAvailable', $lang)
                         else lang:get-language-string('correspondenceTextNotYetAvailable', $lang)
            return element div {
                attribute id {'teiLetter_body'},
                $incipit,
                $summary,
                element span {
                    attribute class {'notAvailable'},
                    $text
                }
            }
         )
         else (transform:transform($doc//tei:text/tei:body, $xslt, $xslParams))
     let $foot := 
        if(config:is-news($docID)) then (:ajax:getNewsFoot($doc, $lang):) ''
        else ()
     
     return ($body, $foot)
    };

(:~
 : Constructs letter header
 :
 : @author Peter Stadler
 : @param $doc document node
 : @param $lang the current language (de|en)
 : @return element
:)
declare function app:construct-title($doc as document-node(), $lang as xs:string) as element()+ {
    (: Support for Albumblätter?!? :)
    let $id := $doc/tei:TEI/string(@xml:id)
    let $date := date:printDate($doc//tei:dateSender/tei:date[1], $lang)
    let $sender := app:printCorrespondentName($doc//tei:sender[1]/*[1], $lang, 'fs')/string()
    let $addressee := app:printCorrespondentName($doc//tei:addressee[1]/*[1], $lang, 'fs')/string()
    let $placeSender := if(functx:all-whitespace($doc//tei:placeSender)) then () else normalize-space($doc//tei:placeSender)
    let $placeAddressee := if(functx:all-whitespace($doc//tei:placeAddressee)) then () else normalize-space($doc//tei:placeAddressee)
    return (
        element tei:title {
            concat($sender, ' ', lower-case(lang:get-language-string('to', $lang)), ' ', $addressee),
            if(exists($placeAddressee)) then concat(' ', lower-case(lang:get-language-string('in', $lang)), ' ', $placeAddressee) else(),
            <tei:lb/>,
            string-join(($placeSender, $date), ', ')
        }
    )
};


(:~
 : Create dateline and author link for website news
 : (Helper Function for ajax:printTranscription())
 :
 : @author Peter Stadler
 : @param $doc the news document node
 : @param $lang the current language (de|en)
 : @return element html:p
 :)
declare %private function app:get-news-foot($doc as document-node(), $lang as xs:string) as element(p)? {
    let $authorID := query:get-authorID($model('doc'))
    let $dateFormat := 
        if ($lang = 'en') then '%A, %B %d, %Y'
                          else '%A, %d. %B %Y'
    return 
        if($authorID) then 
            element p {
                attribute class {'authorDate'},
                app:printCorrespondentName(query:get-author-element($model('doc')), $lang, 'fs'),
                concat(', ', date:strfdate(datetime:date-from-dateTime($doc//tei:publicationStmt/tei:date/@when), $lang, $dateFormat))
            }
        else()
};
