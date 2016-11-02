xquery version "3.1" encoding "UTF-8";

(:~
 : WeGA API XQuery-Module
 :
 : @author Peter Stadler 
 : @version 1.0
 :)
 
module namespace api="http://xquery.weber-gesamtausgabe.de/modules/api";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mei="http://www.music-encoding.org/ns/mei";
import module namespace core="http://xquery.weber-gesamtausgabe.de/modules/core" at "core.xqm";
import module namespace facets="http://xquery.weber-gesamtausgabe.de/modules/facets" at "facets.xqm";
import module namespace search="http://xquery.weber-gesamtausgabe.de/modules/search" at "search.xqm";
import module namespace wdt="http://xquery.weber-gesamtausgabe.de/modules/wdt" at "wdt.xqm";

declare variable $api:WRONG_PARAMETER := QName("http://xquery.weber-gesamtausgabe.de/modules/api", "ParameterError");

declare function api:documents($model as map()) {
    let $wega-docTypes := for $func in wdt:members('indices') return $func(())('name')
    let $ids := 
        if($model('docType') = $wega-docTypes) then 
            core:getOrCreateColl($model('docType'), 'indices', true())/(tei:TEI, tei:ab, tei:person, tei:place)/data(@xml:id)
        else if($model('docType')) then error($api:WRONG_PARAMETER, 'There is no document type "' || $model('docType') || '"')
        else (
            core:getOrCreateColl('letters', 'indices', true()) |
            core:getOrCreateColl('writings', 'indices', true()) |
            core:getOrCreateColl('persons', 'indices', true()) |
            core:getOrCreateColl('diaries', 'indices', true()) |
            core:getOrCreateColl('thematicCommentaries', 'indices', true())
        )/(tei:TEI, tei:ab, tei:person, tei:place)/data(@xml:id)
    return
        api:subsequence($ids, $model) ! map { 'uri' := 'https://weber-gesamtausgabe.de/' || .}
};

(:http://localhost:8080/exist/apps/WeGA-WebApp/dev/api.xql?works=A020062&fromDate=1798-10-10&toDate=1982-06-08&func=facets&format=json&facet=persons&docID=indices&docType=writings:)
(:http://localhost:8080/exist/apps/WeGA-WebApp/dev/api.xql?&fromDate=1801-01-15&toDate=1982-06-08&func=facets&format=json&facet=places&docID=A002068&docType=writings:)
declare function api:facets($model as map()) {
    let $search := search:results(<span/>, map { 'docID' := $model('docID') }, tokenize($model(exist:resource), '/')[last() -2])
    return 
        facets:facets($search?search-results, $model('facet'), -1, 'de')
};

(:~
 :  Helper function for creating a subsequence based on external parameters
~:)
declare %private function api:subsequence($seq as item()*, $model as map()) {
    let $skip := if($model('skip') castable as xs:integer) then $model('skip') cast as xs:integer else 0
    let $limit := if($model('limit') castable as xs:integer) then $model('limit') cast as xs:integer else 0
    return
        if($skip gt 0 and $limit gt 0) then subsequence($seq, $skip, $limit)
        else if($skip gt 0) then subsequence($seq, $skip)
        else if($limit gt 0) then subsequence($seq, 1, $limit)
        else $seq
}; 