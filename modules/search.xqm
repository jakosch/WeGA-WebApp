xquery version "3.0" encoding "UTF-8";

module namespace search="http://xquery.weber-gesamtausgabe.de/modules/search";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mei="http://www.music-encoding.org/ns/mei";
declare namespace templates="http://exist-db.org/xquery/templates";

import module namespace core="http://xquery.weber-gesamtausgabe.de/modules/core" at "core.xqm";
import module namespace config="http://xquery.weber-gesamtausgabe.de/modules/config" at "config.xqm";
import module namespace query="http://xquery.weber-gesamtausgabe.de/modules/query" at "query.xqm";

declare variable $search:valid-params := ('biblioType', 'editors', 'authors' , 'works', 'persons', 
    'occupations', 'docSource', 'composers', 'librettists', 'lyricists', 'dedicatees', 'journals', 
    'docStatus', 'addressee', 'sender', 'textType', 'residences', 'placeOfAddressee', 'placeOfSender');

(:~
 : All results
~:)
declare 
    %templates:default("docType", "letters")
    %templates:wrap
    function search:results($node as node(), $model as map(*), $docType as xs:string) as map(*) {
        let $filters := search:create-filters()
        let $search-results := 
            switch($docType)
            case 'search' return search:query()
            default return core:getOrCreateColl($docType, $model('docID'), true())
        let $filtered-results := search:filter-result($search-results, $filters)
        return
            map {
                'search-results' := $filtered-results,
                'docType' := $docType,
                'filters' := $filters
            }
};

declare 
    %templates:wrap
    function search:results-count($node as node(), $model as map(*)) as xs:string {
        count($model('search-results')) || ' Suchergebnisse'
};

(:~
 : results for one page
~:)
declare 
    %templates:wrap
    %templates:default("page", "1")
    function search:result-page($node as node(), $model as map(*), $page as xs:string) as map(*) {
        let $page := if($page castable as xs:int) then xs:int($page) else 1
        let $entries-per-page := xs:int(config:entries-per-page())
        return
            map {
                'result-page-entries' := subsequence($model('search-results'), ($page - 1) * $entries-per-page + 1, $entries-per-page)
            }
};

(:~
 : Wrapper for dispatching various document types
 : Simply redirects to the right fragment from 'templates/includes'
 :
 :)
declare function search:dispatch-preview($node as node(), $model as map(*)) {
    let $docType := config:get-doctype-by-id($model('result-page-entry')/*/data(@xml:id))
    return
        templates:include($node, $model, 'templates/includes/preview-' || $docType || '.html')
};

declare function search:query() as document-node()* {
    let $searchString := request:get-parameter('q', '')
    let $docType := request:get-parameter('d', 'all')
    let $docType := 
        if($docType = 'all') then map:keys($config:wega-docTypes)
        else map:keys($config:wega-docTypes)[.=$docType]
    return 
        if($searchString) then $docType ! search:fulltext($searchString, .)/root()
        else ()
};

declare %private function search:fulltext($searchString as xs:string, $docType as xs:string) as item()* {
    let $query := search:create-lucene-query-element($searchString)
    let $coll := core:getOrCreateColl($docType, 'indices', true())
    return
        switch($docType)
        case 'persons' return $coll/tei:person[ft:query(., $query)] | $coll//tei:persName[ft:query(., $query)][@type]
        case 'letters' return $coll//tei:body[ft:query(., $query)] | 
            $coll//tei:correspDesc[ft:query(., $query)] | 
            $coll//tei:title[ft:query(., $query)] |
            $coll//tei:incipit[ft:query(., $query)] | 
            $coll//tei:note[ft:query(., $query)][@type = 'summary']
        case 'diaries' return $coll/tei:ab[ft:query(., $query)]
        case 'writings' return $coll//tei:body[ft:query(., $query)] | $coll//tei:title[ft:query(., $query)]
        case 'works' return $coll/mei:mei[ft:query(., $query)] | $coll//mei:title[ft:query(., $query)]
        case 'news' return $coll//tei:body[ft:query(., $query)] | $coll//tei:title[ft:query(., $query)]
        case 'biblio' return $coll//tei:biblStruct[ft:query(., $query)] | $coll//tei:title[ft:query(., $query)] | $coll//tei:author[ft:query(., $query)] | $coll//tei:editor[ft:query(., $query)]
        default return ()
};

declare %private function search:create-lucene-query-element($searchString as xs:string) as element(query) {
    let $tokens := tokenize($searchString, '\s+')
    return
        <query>
            <bool>
                <bool boost="2">{$tokens ! <term occur="must">{.}</term>}</bool>
                <bool>{$tokens ! <wildcard occur="must">{lower-case(.)}*</wildcard>}</bool>
            </bool>
        </query>
};

declare %private function search:create-filters() as map(*) {
    let $params := request:get-parameter-names()[.=$search:valid-params]
    return
        map:new(
            $params ! map:entry(., request:get-parameter(., ()))
        )
};

declare %private function search:filter-result($collection as document-node()*, $filters as map(*)) as document-node()* {
    let $filter := map:keys($filters)[1]
    let $filtered-coll :=
        switch($filter)
        case 'sender' return $collection//@key[.=$filters($filter)][ancestor::tei:sender]/root()
        case 'addressee' return $collection//@key[.=$filters($filter)][ancestor::tei:addressee]/root()
        case 'docStatus' return ($collection/*/@status | $collection//tei:revisionDesc/@status)[.=$filters($filter)]/root()
        case 'placeOfSender' return $collection//tei:placeName[.=$filters($filter)][parent::tei:placeSender]/root()
        case 'placeOfAddressee' return $collection//tei:placeName[.=$filters($filter)][parent::tei:placeAddressee]/root()
        case 'journals' return $collection//tei:title[.=$filters($filter)][@level='j'][not(@type='sub')][ancestor::tei:sourceDesc]/root()
(:        case 'places' return $collection//tei:settlement[ancestor::tei:text or ancestor::tei:ab]:)
        case 'dedicatees' return $collection//mei:persName[@dbkey=$filters($filter)][@role='dte']/root()
        case 'lyricists' return $collection//mei:persName[@dbkey=$filters($filter)][@role='lyr']/root()
        case 'librettists' return $collection//mei:persName[@dbkey=$filters($filter)][@role='lbt']/root()
        case 'composers' return $collection//mei:persName[@dbkey=$filters($filter)][@role='cmp']/root()
        case 'docSource' return $collection//@source[.=$filters($filter)]/root()
        case 'occupations' return $collection//tei:occupation[.=$filters($filter)]/root()
        case 'residences' return $collection//tei:settlement[.=$filters($filter)][parent::tei:residence]/root()
            (: index-keys does not work with multiple whitespace separated keys
                probably need to change to ft:query() someday?!
            :)
        case 'persons' return ($collection//@key[contains(.,$filters($filter))] | $collection//@dbkey[contains(.,$filters($filter))])/root()
        case 'works' return ($collection//@key[contains(.,$filters($filter))] | $collection//@dbkey[contains(.,$filters($filter))])/root()
        case 'authors' return $collection//@key[.=$filters($filter)][parent::tei:author]/root()
        case 'editors' return $collection//@key[.=$filters($filter)][parent::tei:editor]/root()
        case 'biblioType' return $collection//@type[.=$filters($filter)][parent::tei:biblStruct]/root()
        case 'textType' return $collection//@xml:id[starts-with(., $config:wega-docTypes($filters($filter)))]/root()
        default return $collection
    let $newFilter := 
        try { map:remove($filters, $filter) }
        catch * {map:new()}
    return
        if(exists(map:keys($newFilter))) then search:filter-result($filtered-coll, $newFilter)
        else $filtered-coll
};
