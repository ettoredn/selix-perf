tinyMCE.init({
	// General options
	//mode : "textareas",
	mode : "exact",
	elements: "content",
	theme : "advanced",
	//theme : "simple",
	plugins : "safari,pagebreak,style,layer,table,save,advhr,advimage,advlink,emotions,iespell,inlinepopups,insertdatetime,preview,media,searchreplace,print,contextmenu,paste,directionality,fullscreen,noneditable,visualchars,nonbreaking,xhtmlxtras,template",

        entity_encoding : "raw",

	// Theme options
	theme_advanced_buttons1 : "save,print,fullscreen,code,preview,cleanup,|,cut,copy,paste,pastetext,pasteword,|,search,replace,|,undo,redo,|,link,unlink,anchor,image,media,emotions,hr,charmap,iespell,|,insertdate,inserttime,|,ltr,rtl,|,visualaid,|,help",
	theme_advanced_buttons2 : "styleselect,formatselect,fontselect,fontsizeselect,bold,italic,underline,strikethrough,sub,sup,|,justifyleft,justifycenter,justifyright,justifyfull,|,bullist,numlist,|,outdent,indent,blockquote,|,forecolor,backcolor,|,removeformat",
	//theme_advanced_buttons3 : "tablecontrols",
	theme_advanced_buttons3 : "",
	//theme_advanced_buttons4 : "insertlayer,moveforward,movebackward,absolute,|,styleprops,|,cite,abbr,acronym,del,ins,attribs,|,visualchars,nonbreaking,template,pagebreak",
	//theme_advanced_buttons2 : "",
	//theme_advanced_buttons3 : "",
	theme_advanced_buttons4 : "",
	theme_advanced_toolbar_location : "top",
	theme_advanced_toolbar_align : "left",
	theme_advanced_statusbar_location : "bottom",
	theme_advanced_resizing : true,

	// Example content CSS (should be your site CSS)
	content_css : "../templates/admin/wysiwyg.css",

	// Drop lists for link/image/media/template dialogs
	template_external_list_url : "lists/template_list.js",
	external_link_list_url : "lists/link_list.js",
	external_image_list_url : "lists/image_list.js",
	media_external_list_url : "lists/media_list.js",

	// Replace values for the template plugin
	template_replace_values : {
		username : "Some User",
		staffid : "991234"
	}
});

