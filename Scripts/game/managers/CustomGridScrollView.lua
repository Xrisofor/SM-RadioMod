dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

CustomGridScrollView = class( nil )

function CustomGridScrollView.setup( self, hostWidget, gui, name )
	self.gui = gui
	self.name = name
	self.hostWidget = hostWidget

	self.widgetNames = {
		scrollView = name .. "ScrollView",
		scrollBar = name .. "ScrollBar",
		scrollButton = name .. "ScrollButton"
	}

	self.widgets = {
		mainPanel = hostWidget,
		scrollView = FindWidget( hostWidget, self.widgetNames.scrollView ),
		scrollBar = FindWidget( hostWidget, self.widgetNames.scrollBar ),
		scrollButton = FindWidget( hostWidget, self.widgetNames.scrollButton )
	}

	if self.widgets.scrollView.Childs[1] then
		self.baseItem = PopBaseItem( self.widgets.scrollView )
	end

	self.scrollStrength = 2
	self.allowedScrollRange = 0

	self.scrollBarLength = self.widgets.scrollBar.height - self.widgets.scrollButton.height
	assert( self.scrollBarLength > 0 )

	return self
end

function CustomGridScrollView.setGridItemSize( self, width, height )
	assert( width ~= 0 and width <= self.widgets.mainPanel.width )
	assert( height ~= 0 and height <= self.widgets.mainPanel.height )
	self.widgets.scrollView.GridItemSize.width = clamp( width, 1, self.widgets.mainPanel.width )
	self.widgets.scrollView.GridItemSize.height = clamp( height, 1, self.widgets.mainPanel.height )
end

function CustomGridScrollView.addGridItem( self, item )
	self.widgets.scrollView.Childs[#self.widgets.scrollView.Childs+1] = DeepCopy( item )
	local horizontalCount = max( math.floor( self.widgets.scrollView.width / self.widgets.scrollView.GridItemSize.width ), 1 )
	local verticalCount = max( math.floor( ( #self.widgets.scrollView.Childs + horizontalCount - 1 ) / horizontalCount ), 1 )
	local currentHeight = verticalCount * self.widgets.scrollView.GridItemSize.height
	self.allowedScrollRange = math.min( self.widgets.scrollView.height - currentHeight, 0 )
	self.widgets.scrollButton.Visible = self.allowedScrollRange ~= 0
	self.widgets.scrollBar.Visible = self.widgets.scrollButton.Visible
	if self.allowedScrollRange < 0 then
		self.widgets.scrollButton.height = clamp( math.floor( self.widgets.scrollBar.height / max( ( verticalCount - ( self.widgets.mainPanel.height / self.widgets.scrollView.GridItemSize.height ) ), 1 ) ), 24, math.floor( self.widgets.scrollBar.height * 0.75 ) )
		self.scrollBarLength = self.widgets.scrollBar.height - self.widgets.scrollButton.height
	end
end

function CustomGridScrollView.getGridChilds( self )
	return self.widgets.scrollView.Childs
end

function CustomGridScrollView.clearGrid( self )
	self.widgets.scrollView.Childs = {}
end

function CustomGridScrollView.setScrollStrength( self, scrollStrength )
	self.scrollStrength = math.max( scrollStrength * self.widgets.scrollView.GridItemSize.height, 1 )
end

function CustomGridScrollView.handleScroll( self, scrollValue )
	if self.allowedScrollRange == 0 then
		return
	end
	local scrollDir = ( scrollValue > 0 ) and 1 or -1
	local modifiedScroll = scrollDir * self.scrollStrength
	self.widgets.scrollView.GridScrollOffset.top = clamp( self.widgets.scrollView.GridScrollOffset.top + modifiedScroll , self.allowedScrollRange, 0 )
	local buttonPosition = lerp( 0, self.scrollBarLength, self.widgets.scrollView.GridScrollOffset.top / self.allowedScrollRange )
	self.widgets.scrollButton.y = math.floor( buttonPosition )
end

function CustomGridScrollView.handleScrollButtonPressed( self, _, y )
	local _, absY = self.gui:getWidgetAbsolutePosition( self.widgetNames.scrollButton )
	self.buttonPressOffset = y - absY
end

function CustomGridScrollView.handleScrollButtonReleased( self, x, y )

end

function CustomGridScrollView.handleScrollBarPressed( self, x, y )
	self.buttonPressOffset = self.widgets.scrollButton.height / 2
	self:handleScrollButtonDrag( x, y )
end

function CustomGridScrollView.handleScrollButtonDrag( self, x, y )
	local absX, absY = self.gui:getWidgetAbsolutePosition( self.widgetNames.scrollBar )
	x = x - absX
	y = y - absY
	local newY = math.floor( clamp( y - self.buttonPressOffset, 0, self.scrollBarLength ) )
	self.widgets.scrollButton.y = newY
	self.widgets.scrollView.GridScrollOffset.top = math.floor( lerp( 0, self.allowedScrollRange, newY / self.scrollBarLength ) )
end

function CustomGridScrollView.resetScroll( self )
	self.widgets.scrollView.GridScrollOffset.top = 0
	self.widgets.scrollButton.y = 0
end