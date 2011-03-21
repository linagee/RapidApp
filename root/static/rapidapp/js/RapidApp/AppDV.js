Ext.ns('Ext.ux.RapidApp.AppDV');


Ext.ux.RapidApp.AppDV.DataView = Ext.extend(Ext.DataView, {
	 //defaultType: 'textfield',
	 initComponent : function(){
			Ext.each(this.items,function(item) {
				item.ownerCt = this;
			},this);
			Ext.ux.RapidApp.AppDV.DataView.superclass.initComponent.call(this);
			this.components = [];
			
			this.on('click',this.click_controller,this);
	 },
	 
	 refresh : function(){
		  Ext.destroy(this.components);
		  this.components = [];
		  Ext.ux.RapidApp.AppDV.DataView.superclass.refresh.call(this);
		  this.renderItems(0, this.store.getCount() - 1);
	 },
	 onUpdate : function(ds, record){
		  var index = ds.indexOf(record);
		  if(index > -1){
				this.destroyItems(index);
		  }
		  Ext.ux.RapidApp.AppDV.DataView.superclass.onUpdate.apply(this, arguments);
		  if(index > -1){
				this.renderItems(index, index);
		  }
	 },
	 onAdd : function(ds, records, index){
		  var count = this.all.getCount();
		  Ext.ux.RapidApp.AppDV.DataView.superclass.onAdd.apply(this, arguments);
		  if(count !== 0){
				this.renderItems(index, index + records.length - 1);
		  }
	 },
	 
	 onRemove : function(ds, record, index){
		  this.destroyItems(index);
		  Ext.ux.RapidApp.AppDV.DataView.superclass.onRemove.apply(this, arguments);
	 },
	 onDestroy : function(){
		  Ext.ux.RapidApp.AppDV.DataView.superclass.onDestroy.call(this);
		  Ext.destroy(this.components);
		  this.components = [];
	 },
	 renderItems : function(startIndex, endIndex){
		  var ns = this.all.elements;
		  var args = [startIndex, 0];
		  for(var i = startIndex; i <= endIndex; i++){
				var r = args[args.length] = [];
				for(var items = this.items, j = 0, len = items.length, c; j < len; j++){
				
					// c = items[j].render ?
					//	  c = items[j].cloneConfig() :
						
						// RapidApp specific:
						// Components are stored as serialized JSON to ensure they
						// come out exactly the same every time:
						c = Ext.create(Ext.decode(items[j]), this.defaultType);
						  
					 r[j] = c;
					 if(c.renderTarget){
						  c.render(Ext.DomQuery.selectNode(c.renderTarget, ns[i]));
					 }else if(c.applyTarget){
						  c.applyToMarkup(Ext.DomQuery.selectNode(c.applyTarget, ns[i]));
					 }else{
						  c.render(ns[i]);
					 }
					 
					 if(Ext.isFunction(c.setValue) && c.applyValue){
						  c.setValue(this.store.getAt(i).get(c.applyValue));
						  c.on('blur', function(f){
							this.store.getAt(this.index).data[this.dataIndex] = f.getValue();
						  }, {store: this.store, index: i, dataIndex: c.applyValue});
					 }
					 
				}
		  }
		  this.components.splice.apply(this.components, args);
	 },
	 destroyItems : function(index){
		  Ext.destroy(this.components[index]);
		  this.components.splice(index, 1);
	 },
	click_controller: function(dv, index, domEl, event) {
		var target = event.getTarget(null,null,true);
		
		// Limit processing to click nodes within this dataview (i.e. not in our submodules)
		var topmostEl = target.parent('div.appdv-tt-generated.' + dv.id);
		if(!topmostEl) { 
			// Temporary: map to old function:
			return Ext.ux.RapidApp.AppDV.click_handler.apply(this,arguments);
			return; 
		}
		if(!topmostEl.child('div.clickable')) { return; }
		
		var editEl = target.parent('div.editable-value');
		if(editEl) {
			return this.handle_edit_click(target,editEl,index);
		}
	
	
	},
	handle_edit_click: function (target,editEl,index) {
		var fieldnameEl = editEl.child('div.field-name');
		if(!fieldnameEl) { return; }
		
		var fieldname = fieldnameEl.dom.innerHTML;
		if(!fieldname) { return; }
		console.log(fieldname);
		
		//var dataEl = editEl.down('div.data');
		//console.dir(editEl);
		
		var dataWrap = editEl.child('table').child('tr').child('td.data');
		var dataEl = dataWrap.child('div.data-inner');
		console.dir(dataEl);
		
		var Store = this.getStore()
		var Record = Store.getAt(index);
		
		if (editEl.hasClass('editing')) {
		
			var Field = this.FieldCmp[index][fieldname];
			
			if(target.hasClass('save')) {
				var val = Field.getValue();
				Record.set(fieldname,val);
				Store.save();
			}
			else {
				if(!target.hasClass('cancel')) { return; }
			}
		
			editEl.removeClass('editing');
			
			//console.dir(dv.FieldCmp[index][fieldname].contentEl);
			this.FieldCmp[index][fieldname].contentEl.appendTo(dataWrap);
			this.FieldCmp[index][fieldname].destroy();
			//dataEl.setVisible(true);
		}
		else {
			editEl.addClass('editing');

			var cnf = {};
			Ext.apply(cnf,this.FieldCmp_cnf[fieldname]);
			Ext.apply(cnf,{
				value: Record.data[fieldname],
				//renderTo: valueEl
				renderTo: dataWrap,
				contentEl: dataEl
			});
			
			//console.dir(dataEl);
			
			if(!cnf.width) {	cnf.width = dataEl.getWidth(); }
			if(!cnf.height) { cnf.height = dataEl.getHeight(); }
			if(cnf.minWidth) { if(!cnf.width || cnf.width < cnf.minWidth) { cnf.width = cnf.minWidth; } }
			if(cnf.minHeight) { if(!cnf.height || cnf.height < cnf.minHeight) { cnf.height = cnf.minHeight; } }
					
			var Field = Ext.ComponentMgr.create(cnf,'field');

			if(Field.resizable) {
				var resizer = new Ext.Resizable(Field.wrap, {
					pinned: true,
					handles: 's',
					//handles: 's,e,se',
					dynamic: true,
					listeners : {
						'resize' : function(resizable, height, width) {
							Field.setSize(height,width);
						}
					}
				});
			}

			Field.show();
			//dataEl.setVisibilityMode(Ext.Element.DISPLAY);
			//dataEl.setVisible(false);
			
			//Field.getEl().applyStyle(dataEl.getStyle());
			
			if(!Ext.isObject(this.FieldCmp)) { this.FieldCmp = {} }
			if(!Ext.isObject(this.FieldCmp[index])) { this.FieldCmp[index] = {} }
			this.FieldCmp[index][fieldname] = Field;
				
				
			
		}
		//console.dir(editEl);
	}
});
Ext.reg('appdv', Ext.ux.RapidApp.AppDV.DataView);

Ext.ux.RapidApp.AppDV.click_handler = function(dv, index, domEl, event) {
	var target = event.getTarget(null,null,true);

	// Limit processing to click nodes within this dataview (i.e. not in our submodules)
	if(!target.findParent('div.appdv-click.' + dv.id)) { return; }

	var clickEl = target;
	if(!clickEl.hasClass('appdv-click-el')) { clickEl = target.parent('div.appdv-click-el'); }
	if(!clickEl) { return; }
	
	var node = clickEl.dom;
	// Needed for IE:
	var classList = node.classList;
	if(! classList) {
		classList = node.className.split(' ');
	}
	
	var fieldname = null;
	Ext.each(classList,function(cls) {
		var arr = cls.split('edit:');
		if (arr.length > 1) {
			fieldname = arr[1];
		}
	});
	
	if (!fieldname) { return; }
	//console.log(fieldname);
	
	var topEl = new Ext.Element(domEl);
	
	//console.dir(topEl);
	
	var valueEl = topEl.child('div.appdv-field-value.' + fieldname);
	//if (!valueEl) { return; }
	
	var dataEl = valueEl.child('div.data');
	var fieldEl = valueEl.child('div.fieldholder');
	var Store = dv.getStore()
	var Record = Store.getAt(index);
	
	if (valueEl.hasClass('editing')) {
	
		var Field = dv.FieldCmp[index][fieldname];
		
		if(!target.hasClass('cancel')) {
			var val = Field.getValue();
			Record.set(fieldname,val);
			Store.save();
		}
	
		valueEl.removeClass('editing');
		
		//console.dir(dv.FieldCmp[index][fieldname].contentEl);
		dv.FieldCmp[index][fieldname].contentEl.appendTo(valueEl);
		dv.FieldCmp[index][fieldname].destroy();
		//dataEl.setVisible(true);
	}
	else {
		valueEl.addClass('editing');
		
		var cnf = {};
		Ext.apply(cnf,dv.FieldCmp_cnf[fieldname]);
		Ext.apply(cnf,{
			value: Record.data[fieldname],
			//renderTo: valueEl
			renderTo: fieldEl,
			contentEl: dataEl
		});
		
		//console.dir(dataEl);
		
		if(!cnf.width) {	cnf.width = dataEl.getWidth(); }
		if(!cnf.height) { cnf.height = dataEl.getHeight(); }
		if(cnf.minWidth) { if(!cnf.width || cnf.width < cnf.minWidth) { cnf.width = cnf.minWidth; } }
		if(cnf.minHeight) { if(!cnf.height || cnf.height < cnf.minHeight) { cnf.height = cnf.minHeight; } }
				
		var Field = Ext.ComponentMgr.create(cnf,'field');

		if(Field.resizable) {
			var resizer = new Ext.Resizable(Field.wrap, {
				pinned: true,
				handles: 's',
				//handles: 's,e,se',
				dynamic: true,
				listeners : {
					'resize' : function(resizable, height, width) {
						Field.setSize(height,width);
					}
				}
			});
		}

		Field.show();
		//dataEl.setVisibilityMode(Ext.Element.DISPLAY);
		//dataEl.setVisible(false);
		
		//Field.getEl().applyStyle(dataEl.getStyle());
		
		if(!Ext.isObject(dv.FieldCmp)) { dv.FieldCmp = {} }
		if(!Ext.isObject(dv.FieldCmp[index])) { dv.FieldCmp[index] = {} }
		dv.FieldCmp[index][fieldname] = Field;
	}
}




