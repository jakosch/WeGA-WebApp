xquery version "3.1" encoding "UTF-8";

module namespace search="http://xquery.weber-gesamtausgabe.de/modules/search";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mei="http://www.music-encoding.org/ns/mei";
declare namespace xhtml="http://www.w3.org/1999/xhtml";

import module namespace kwic="http://exist-db.org/xquery/kwic";
import module namespace templates="http://exist-db.org/xquery/templates" at "/db/apps/shared-resources/content/templates.xql";
import module namespace core="http://xquery.weber-gesamtausgabe.de/modules/core" at "core.xqm";
import module namespace norm="http://xquery.weber-gesamtausgabe.de/modules/norm" at "norm.xqm";
import module namespace config="http://xquery.weber-gesamtausgabe.de/modules/config" at "config.xqm";
import module namespace query="http://xquery.weber-gesamtausgabe.de/modules/query" at "query.xqm";
import module namespace str="http://xquery.weber-gesamtausgabe.de/modules/str" at "str.xqm";
import module namespace wdt="http://xquery.weber-gesamtausgabe.de/modules/wdt" at "wdt.xqm";
import module namespace lang="http://xquery.weber-gesamtausgabe.de/modules/lang" at "lang.xqm";
import module namespace wega-util="http://xquery.weber-gesamtausgabe.de/modules/wega-util" at "wega-util.xqm";
import module namespace functx="http://www.functx.com";

declare variable $search:ERROR := QName("http://xquery.weber-gesamtausgabe.de/modules/search", "Error");

(: 
 : a subset of $config:wega-docTypes. 
 : Finally, all of these should be supported 
 :)
declare variable $search:wega-docTypes := for $func in wdt:members('search') return $func(())('name');

(: params for filtering the result set :)
declare variable $search:valid-params := ('biblioType', 'editors', 'authors', 'works', 'persons', 'orgs',
    'occupations', 'docSource', 'composers', 'librettists', 'lyricists', 'dedicatees', 'journals', 
    'docStatus', 'addressee', 'sender', 'textType', 'residences', 'places', 'placeOfAddressee', 'placeOfSender',
    'fromDate', 'toDate', 'undated', 'hideRevealed', 'docTypeSubClass', 'sex', 'surnames', 'forenames', 
    'asksam-cat', 'vorlageform', 'einrichtungsform', 'placenames');

(:~
 : Main function called from the templating module
 : All results will be created here for the search page as well as for list views (indices pages)
~:)
declare 
    %templates:default("docType", "letters")
    %templates:wrap
    function search:results($node as node(), $model as map(*), $docType as xs:string) as map(*) {
        let $filters := map { 'filters' := search:create-filters(), 'api-base' := core:link-to-current-app('/api/v1')}
        return
            switch($docType)
            (: search page :)
            case 'search' return search:search(map:new(($model, $filters, map:entry('docID', 'indices'))))
            (: controller sends docType=persons which needs to be turned into "personsPlus" here :)
            case 'persons' return search:list(map:new(($filters, map:put($model, 'docType', 'personsPlus'))))
            (: various list views :)
            default return search:list(map:new(($filters, map:put($model, 'docType', $docType))))
};

(:~
 : Print the ammount of hits
 : To be called from an HTML template
~:)
declare 
    %templates:wrap
    %templates:default("lang", "en")
    function search:results-count($node as node(), $model as map(*), $lang as xs:string) as xs:string {
        count($model('search-results')) || ' ' || lang:get-language-string('searchResults', $lang)
};

(:~
 : Write the sanitized query string into the search text input for reuse
 : To be called from an HTML template
~:)
declare function search:inject-value($node as node(), $model as map(*)) as element(input) {
    element {name($node)} {
        $node/@*[not(name(.) = 'value')],
        if($model('query-string-org') ne '') then attribute {'value'} {$model('query-string-org')}
        else ()
    }
};

(:~
 : Push the results for one page to the $model
 : $model?result-page-entries will be a sequence of document-node()*
 : $model?result-page-hits-per-entry will be a map(), consisting of document IDs as key and the fulltext hits as value (if appropriate).
~:)
declare 
    %templates:wrap
    %templates:default("page", "1")
    function search:result-page($node as node(), $model as map(*), $page as xs:string) as map(*) {
        let $page := if($page castable as xs:int) then xs:int($page) else 1
        let $entries-per-page := xs:int(config:entries-per-page())
        let $subseq := subsequence($model('search-results'), ($page - 1) * $entries-per-page + 1, $entries-per-page)
        let $docs := 
            (: This whole code block is not very elegant:
             : the results of the fulltext search are of type map()* and need to be turned into document-node
             : the results of the list of examples from the spec pages are elements and need *not* to be processed
             : other searches and/or list views simply return document-node()*
            :)
            for $doc in $subseq
            return
                if($doc instance of document-node()) then $doc
                else if($doc instance of map()) then $doc?doc
                else if($doc instance of element()) then $doc 
                else if($doc instance of node()) then error($search:ERROR, 'unable to process node: ' || functx:node-kind($doc) || ' ' || name($doc))
                else if($doc instance of xs:anyAtomicType) then error($search:ERROR, 'unable to process atomic type: ' || functx:atomic-type($doc))
                else error($search:ERROR, 'unknown result entry')
        let $result-page-hits-per-entry := map:new(
            for $doc in $subseq
            return (
                if($doc instance of map() and exists($doc?hits)) then 
                    map:entry($doc?doc/*/data(@xml:id), $doc?hits)
                else ()
            )
        )
        return
            map {
                'result-page-entries' := $docs,
                'result-page-hits-per-entry' := $result-page-hits-per-entry
            }
};

(:~
 : Wrapper for dispatching various document types
 : Simply redirects to the right fragment from 'templates/includes'
 :)
declare 
    %templates:default("usage", "")
    function search:dispatch-preview($node as node(), $model as map(*), $usage as xs:string) {
        let $docID := $model('result-page-entry')/*/data(@xml:id)
        let $docType := 
            (: Preview orgs with the person template :)
            if(config:is-org($docID)) then 'persons'
            else if(config:is-var($docID)) then 'documents'
            else config:get-doctype-by-id($docID)
(:        let $log := util:log-system-out($model('docType') || ' - ' || $model('docID')):)
        (: Need to distinguish between contacts and other person previews :)
        let $usage := if(wdt:personsPlus(($model('docID')))('check')() and $model('docType') = 'contacts') then 'contacts' else ''
        (: Since docID will be overwritten by app:preview we need to preserve it to know what the parent page is :)
        let $newModel := map:new(($model, map:entry('parent-docID', $model('docID')), map:entry('usage', $usage)))
        return
            templates:include($node, $newModel, 'templates/includes/preview-' || $docType || '.html')
};

(:~
 : KWIC output
 :)
declare 
    %templates:wrap
    function search:kwic($node as node(), $model as map(*)) as element(xhtml:p)* {
        if(exists($model('result-page-hits-per-entry'))) then 
            let $hits := $model('result-page-hits-per-entry')($model('docID'))
            let $expanded := $hits ! kwic:expand(.)
            let $summaries := $expanded//exist:match ! kwic:get-summary(./root(), ., <config width="40"/>)
            return
                (: merge different hits from e.g. tei:TEI and tei:body by calling functx:distinct-deep() on the output html:p :)
                functx:distinct-deep($summaries)
        else ()
};

(:~
 : Search results and other goodies for the *search* page 
~:)
declare %private function search:search($model as map(*)) as map(*) {
    let $updatedModel := search:prepare-search-string($model)
    let $docTypes := 
        if($updatedModel?query-docTypes = 'all') then ($search:wega-docTypes, 'var') (: silently add 'var' (= special pages, e.g. "Impressum/About" or "Sonderband/Special Volume") to the list of docTypes :)
        else $search:wega-docTypes[.=$updatedModel?query-docTypes]
    let $base-collection := 
        if($updatedModel('query-string-org')) then $docTypes ! core:getOrCreateColl(., 'indices', true())
        else ()
    let $filtered-results := 
        if(exists($updatedModel('filters'))) then 
            for $docType in $docTypes 
            return search:filter-result($base-collection, $updatedModel?filters, $docType)
        else $base-collection
    let $fulltext-search :=
        if($updatedModel('query-string')) then search:merge-hits($docTypes ! search:fulltext($filtered-results, $updatedModel('query-string'), $updatedModel?filters, .))
        else $filtered-results 
    return
        map:new(($updatedModel, map:entry('search-results', $fulltext-search)))
};  

(:~
 : Search results and other goodies for the *list view* pages 
~:)
declare %private function search:list($model as map(*)) as map(*) {
    let $coll := core:getOrCreateColl($model('docType'), $model('docID'), true())
    let $search-results := 
        if(exists($model('filters'))) then search:filter-result($coll, $model('filters'), $model('docType'))
        else $coll
    let $sorted-results := wdt:lookup($model('docType'), $search-results)('sort')( map { 'personID' := $model('docID')} )
    return
        map:merge((
            $model,
            map {
                'filters' := $model('filters'),
                'search-results' := $sorted-results,
                'earliestDate' := if($model('docType') = ('letters', 'writings', 'diaries', 'news', 'biblio')) then search:get-earliest-date($model('docType'), $model('docID')) else (),
                'latestDate' := if($model('docType') = ('letters', 'writings', 'diaries', 'news', 'biblio')) then search:get-latest-date($model('docType'), $model('docID')) else ()
            }
        ))
};  

(:~
 : Sorting and merging search results
 : Helper function for search:search()
~:)
declare %private function search:merge-hits($hits as item()*) as map()* {
    for $hit in $hits
    group by $doc := $hit/root()
    let $score := sum($hit ! ft:score(.))
    order by $score descending 
    return
        map { 
            'doc' := $doc,
            'hits' := $hit,
            'score' := $score
        }
};

(:~
 :  Do a full text search 
 :  by looking up the appropriate search function in the wdt module 
~:)
declare %private function search:fulltext($items as item()*, $searchString as xs:string, $filters as map(), $docType as xs:string) as item()* {
    let $query := search:create-lucene-query-element($searchString)
    let $search-func := wdt:lookup(., $items)?search
    return
        try { $search-func($query) }
        catch * { error($search:ERROR, 'failed to search collection with docType "' || $docType || '"') }
};

(:~
 : Parse the query string and create an XML query element for the lucene search
~:)
declare %private function search:create-lucene-query-element($searchString as xs:string) as element(query) {
    let $groups := analyze-string($searchString, '(-?"(.+?)")')/* (: split into fn:match – for expressions in parentheses – and fn:non-match elements :)
    let $queryElement := function($elementName as xs:string, $token as item()) as element() {
        element {$elementName} {
            attribute occur {
                if(starts-with($token, '-')) then 'not'
                else if($token instance of node() and $token/ancestor::fn:group[starts-with(., '-')]) then 'not'
                else 'must'
            },
            if(starts-with($token, '-')) then substring($token, 2)
            else string($token)
        }
    }
    let $term-search := <bool boost="5">{$groups ! (if(./self::fn:match) then $queryElement('phrase', .//fn:group[@nr='2']) else (tokenize(str:normalize-space(.), '\s') ! $queryElement('term', .)))}</bool>
    (:  Suppress additional searches when the search string consists of expressions in parentheses only  :)
    let $wildcard-search := if($groups[not(functx:all-whitespace(self::fn:non-match))]) then <bool boost="2">{$groups ! (if(./self::fn:match) then $queryElement('phrase', .//fn:group[@nr='2']) else (tokenize(str:normalize-space(.), '\s') ! $queryElement('wildcard', lower-case(.) || '*')))}</bool> else ()
    let $regex-search := if($groups[not(functx:all-whitespace(self::fn:non-match))]) then <bool>{$groups ! (if(./self::fn:match) then $queryElement('phrase', .//fn:group[@nr='2']) else (tokenize(str:normalize-space(.), '\s') ! search:additional-mappings(lower-case(.))))}</bool> else ()
    let $q :=
        <query>
            <bool>{
                $term-search,
                $wildcard-search,
                $regex-search
            }</bool>
        </query>
(:    let $log := util:log-system-out($groups):)
(:    let $log := util:log-system-out($q):)
    return 
        $q
};

(:~
 : Helper function for search:create-lucene-query-element()
 : Adds additional character mappings to the search, e.g. "Rowenstrunk -> Roewenstrunk"
 : This is applied *after* the unicode normalization, so the input $str is already without diacritics
 :
 : @param $str a search token, derived from the input query string
 : @return a <regex> element for use in XML lucene syntax
~:)
declare %private function search:additional-mappings($str as xs:string) as element(regex) {
    <regex occur="must">{
        functx:replace-multi($str, 
            ('"', '[ck]', 'ae?', 'oe?', 'ue?', 'ß', 'th?', '((ph)|f)', '[yi]e?'), 
            ('', '(c|k)', 'ae?', 'oe?', 'ue?', 'ss', 'th?', '((ph)|f)', '[yi]e?') 
        )
    }.*</regex>
};

(:~
 : Creates a map of to-be-applied-filters from URL request parameters
~:)
declare %private function search:create-filters() as map(*) {
    let $params := request:get-parameter-names()[.=$search:valid-params]
    return
        map:new(
            (: "undated" takes precedence over date filter :)
            if($params[.='undated']) then $params[not(.= ('fromDate', 'toDate'))] ! map:entry(., request:get-parameter(., ()))
            else $params ! map:entry(., request:get-parameter(., ()))
        )
};

(:~  
 : Filters collection according to given facets and date constraints
 : Recursively applies this function until the filter map is empty
~:)
declare %private function search:filter-result($collection as document-node()*, $filters as map(*), $docType as xs:string) as document-node()* {
    let $filter := map:keys($filters)[1]
    let $filtered-coll := 
      if($filter) then 
        if($filter = ('undated')) then () 
        else if($filter = ('fromDate', 'toDate')) then wdt:lookup($docType, $collection)?filter-by-date(try {$filters?fromDate cast as xs:date} catch * {()}, try {$filters?toDate cast as xs:date} catch * {()} )
        else if($filter = 'textType') then search:textType-filter($collection, $filters)
        else if($filter = 'hideRevealed') then search:revealed-filter($collection, $filters)
        (: exact search for terms -> range:eq :)
        else if($filter = ('journals', 'forenames', 'surnames', 'sex', 'occupations')) then query:get-facets($collection, $filter)[range:eq(.,$filters($filter))]/root()
        (: range:contains for tokens within key values  :)
        else query:get-facets($collection, $filter)[range:contains(.,$filters($filter))]/root()
      else $collection
    let $newFilter :=
        if($filter = ('fromDate', 'toDate')) then 
            try { map:remove(map:remove($filters, 'toDate'), 'fromDate') }
            catch * {()}
        else 
            try { map:remove($filters, $filter) }
            catch * {map:new()}
    return
        if(exists(map:keys($newFilter))) then search:filter-result($filtered-coll, $newFilter, $docType)
        else $filtered-coll
};

(:~
 : Helper function for search:filter-result()
 : Applies chronological filter 'fromDate' and 'toDate'
~:)
(:declare %private function search:date-filter($collection as document-node()*, $docType as xs:string, $filters as map(*)) as document-node()* {
    let $filter := map:keys($filters)[1]
    return
        switch($docType)
        case 'biblio' return
            if ($filter = 'undated') then ($collection intersect core:undated($docType))/root()
            else if ($filter = 'fromDate') then ( 
                (\: checking only the year for the lower threshold otherwise we'll miss date=1810 when checking 1810-01-01 :\)
                $collection//tei:date[range:field-ge('date-when', substring($filters($filter), 1, 4))] |
                $collection//tei:date[range:field-ge('date-notBefore', substring($filters($filter), 1, 4))] |
                $collection//tei:date[range:field-ge('date-notAfter', substring($filters($filter), 1, 4))] |
                $collection//tei:date[range:field-ge('date-from', substring($filters($filter), 1, 4))] |
                $collection//tei:date[range:field-ge('date-to', substring($filters($filter), 1, 4))]
                )[parent::tei:imprint]/root()
            else ( 
                $collection//tei:date[range:field-le('date-when', $filters($filter))] |
                $collection//tei:date[range:field-le('date-notBefore', $filters($filter))] |
                $collection//tei:date[range:field-le('date-notAfter', $filters($filter))] |
                $collection//tei:date[range:field-le('date-from', $filters($filter))] |
                $collection//tei:date[range:field-le('date-to', $filters($filter))]
                )[parent::tei:imprint]/root()
        case 'diaries' return 
            if ($filter = 'fromDate') then $collection//tei:ab[@n >= $filters($filter)]/root()
            else $collection//tei:ab[@n <= $filters($filter)]/root()
        case 'letters' return
            if ($filter = 'undated') then ($collection intersect core:undated($docType))/root()
            else if ($filter = 'fromDate') then ( 
                $collection//tei:date[range:field-ge('date-when', $filters($filter))] |
                $collection//tei:date[range:field-ge('date-notBefore', $filters($filter))] |
                $collection//tei:date[range:field-ge('date-notAfter', $filters($filter))] |
                $collection//tei:date[range:field-ge('date-from', $filters($filter))] |
                $collection//tei:date[range:field-ge('date-to', $filters($filter))]
                )[parent::tei:correspAction]/root()
            else ( 
                $collection//tei:date[range:field-le('date-when', $filters($filter))] |
                $collection//tei:date[range:field-le('date-notBefore', $filters($filter))] |
                $collection//tei:date[range:field-le('date-notAfter', $filters($filter))] |
                $collection//tei:date[range:field-le('date-from', $filters($filter))] |
                $collection//tei:date[range:field-le('date-to', $filters($filter))]
                )[parent::tei:correspAction]/root()
        case 'news' return
            if ($filter = 'undated') then ($collection intersect core:undated($docType))/root()
            (\: news enthalten dateTime im date/@when :\)
            else  if ($filter = 'fromDate') then $collection//tei:date[substring(@when,1,10) >= $filters($filter)][parent::tei:publicationStmt]/root()
            else $collection//tei:date[substring(@when,1,10) <= $filters($filter)][parent::tei:publicationStmt]/root()
        case 'persons' case 'orgs' return ()
        case 'writings' return
            if ($filter = 'undated') then ($collection intersect core:undated($docType))/root()
            else if ($filter = 'fromDate') then ( 
                $collection//tei:date[range:field-ge('date-when', $filters($filter))] |
                $collection//tei:date[range:field-ge('date-notBefore', $filters($filter))] |
                $collection//tei:date[range:field-ge('date-notAfter', $filters($filter))] |
                $collection//tei:date[range:field-ge('date-from', $filters($filter))] |
                $collection//tei:date[range:field-ge('date-to', $filters($filter))]
                )[parent::tei:imprint][ancestor::tei:sourceDesc]/root()
            else ( 
                $collection//tei:date[range:field-le('date-when', $filters($filter))] |
                $collection//tei:date[range:field-le('date-notBefore', $filters($filter))] |
                $collection//tei:date[range:field-le('date-notAfter', $filters($filter))] |
                $collection//tei:date[range:field-le('date-from', $filters($filter))] |
                $collection//tei:date[range:field-le('date-to', $filters($filter))]
                )[parent::tei:imprint][ancestor::tei:sourceDesc]/root()
        case 'works' return ()
        case 'places' return ()
        default return $collection
};
:)

(:~
 : Helper function for search:filter-result()
 : Applies textType filter for backlinks
~:)
declare %private function search:textType-filter($collection as document-node()*, $filters as map(*)) as document-node()* {
    wdt:lookup($filters?textType, 
        $collection
    )('sort')(map {})
};

declare %private function search:revealed-filter($collection as document-node()*, $filters as map(*)) as document-node()* {
    $collection//tei:correspDesc[not(@n='revealed')]/root()
};

(:~
 : 
~:)
declare %private function search:get-earliest-date($docType as xs:string, $cacheKey as xs:string) as xs:string? {
    let $catalogue := norm:get-norm-doc($docType)
    return
        switch ($docType)
            case 'diaries' return 
                if($cacheKey = ('A002068','indices')) then ($catalogue//norm:entry[text()])[1]/text()
                else ()
            case 'letters' return 
                if($cacheKey eq 'indices') then ($catalogue//norm:entry[text()])[1]/text()
                else ($catalogue//norm:entry[range:contains(@addresseeID, $cacheKey)][text()] | $catalogue//norm:entry[range:contains(@authorID, $cacheKey)][text()])[1]/text()
            case 'news' case 'biblio' return
                (: reverse order :)
                if($cacheKey eq 'indices') then ($catalogue//norm:entry[text()])[last()]/text()
                else ($catalogue//norm:entry[range:contains(@authorID, $cacheKey)][text()])[last()]/text()
            case 'persons' case 'orgs' return ()
            case 'writings' return 
                if($cacheKey eq 'indices') then ($catalogue//norm:entry[text()])[1]/text()
                else ($catalogue//norm:entry[range:contains(@authorID, $cacheKey)][text()])[1]/text()
            case 'works' return ()
            case 'places' return ()
            default return ()
};

(:~
 : 
~:)
declare %private function search:get-latest-date($docType as xs:string, $cacheKey as xs:string) as xs:string? {
    let $catalogue := norm:get-norm-doc($docType)
    return
        switch ($docType)
            case 'diaries' return 
                if($cacheKey = ('A002068','indices')) then ($catalogue//norm:entry[text()])[last()]/text()
                else ()
            case 'letters' return 
                if($cacheKey eq 'indices') then ($catalogue//norm:entry[text()])[last()]/text()
                else ($catalogue//norm:entry[range:contains(@addresseeID, $cacheKey)][text()] | $catalogue//norm:entry[range:contains(@authorID, $cacheKey)][text()])[last()]/text()
            case 'news' case 'biblio' return
                (: reverse order :)
                if($cacheKey eq 'indices') then ($catalogue//norm:entry[text()])[1]/text()
                else ($catalogue//norm:entry[range:contains(@authorID, $cacheKey)][text()])[1]/text()
            case 'persons' case 'orgs' return ()
            case 'writings' return
                if($cacheKey eq 'indices') then ($catalogue//norm:entry[text()])[last()]/text()
                else ($catalogue//norm:entry[range:contains(@authorID, $cacheKey)][text()])[last()]/text()
            case 'works' return ()
            case 'places' return ()
            default return ()
};

(:~
 : Read query string and parameters from URL 
 :
 : @return a map with sanitized query string, parameters and recognized dates
~:)
declare %private function search:prepare-search-string($model as map()) as map(*) {
    let $query-docTypes := request:get-parameter('d', 'all') ! str:sanitize(.)
    let $query-string-org := request:get-parameter('q', '')
    let $sanitized-query-string := str:normalize-space(str:sanitize(string-join($query-string-org, ' ')))
    let $analyzed-query-string := analyze-string($sanitized-query-string, '\d{4}-\d{2}-\d{2}')
    let $dates := $analyzed-query-string/fn:match/text()
    let $query-string := str:normalize-space(string-join($analyzed-query-string/fn:non-match/text(), ' '))
    let $filters := 
        (: if only one date is given in the query string, we set both toDate and fromDate on date  :)
        if(count($dates) = 1) then map:put(map:put($model?filters, 'toDate', $dates), 'fromDate', $dates)
        (: if two (or more!) dates are given in the query string, we set fromDate to the first and toDate to the second date :)
        else if(count($dates) gt 1) then map:put(map:put($model?filters, 'toDate', $dates[2]), 'fromDate', $dates[1])
        else $model?filters
    return
        map:new((
            $model, 
            map {
                'filters' := $filters, (: the original filters from $model gets overridden :)
                'query-string' := wega-util:strip-diacritics($query-string), (: flatten input search string, e.g. 'mèhul' --> 'mehul' for use with the NoDiacriticsStandardAnalyzer :) 
                'query-docTypes' := $query-docTypes,
                'query-string-org' := $query-string-org
            }
        ))
};
