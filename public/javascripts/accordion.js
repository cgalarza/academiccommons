$(document).ready(function() {
 $('#facets ul').each(function(){
   var ul = $(this);
   // find all ul's that don't have any span descendants with a class of "selected"
   if($('li.facet_selected', ul).length == 0){
        // hide it
        ul.hide();
        // attach the toggle behavior to the h3 tag
        $(ul.parent().children('.toggle')).click(function(){
           // toggle the next ul sibling
           $(this).next('ul').slideToggle();
       });
   }
});
});
