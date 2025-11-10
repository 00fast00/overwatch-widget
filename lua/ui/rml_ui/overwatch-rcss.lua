-- AUTO Generated: DO NOT EDIT
return [[
body {
    font-family: "Poppins";
    font-size: 10dp;
}

div {
    display: block;
}

p {
    display: block;
}

h1 {
    display: block;
    font-family: "Exo 2";
    font-size: 1.5rem;
    font-weight: bold;
}

.font-bold {
    font-weight: 700;
}

.text-sm {
    font-size: 14dp;
}

/* Color utilities */
.text-dark {
    color: #4a4a4a;
}

.bg-primary {
    background-color: #FDC04C;
}

.width-10 {
    width: 10%;
}

.width-70 {
    width: 70%;
}

#overwatch-widget {
    /* positional properties */
    position: absolute;
    bottom: 200dp;
    right: 300dp;
    width: 500dp;
    height: 500dp;
    background: #060606ba;
    border-radius: 5dp;
    padding: 12dp;
}

/* Draggable handle styles */
.move_handle {
    height: 1.5rem;
    width: 80%;
    cursor: move;
    text-align: left;
    position: absolute;
    top: 0;
    left: 0;
    z-index: 5;
    clip: always;
}

.size_handle {
    background-color: #000000ff;
    height: 1.5rem;
    width: 1.5rem;
    cursor: move;
    text-align: left;
    position: absolute;
    bottom: 0;
    right: 0;
    z-index: 5;
    clip: always;
}

#widget-container {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
}

#log {
    width: 100%;
    height: 100%;
}

#log scrollbarvertical {
    position: absolute;
    top: 0;
    right: -12dp;
}

#logs {
    overflow: hidden scroll;
    width: 100%;
    height: 100%;
}

#logs thead tr td {
    font-family: "Exo 2";
    font-weight: 700;
}

#logsum {
    position: absolute;
    right: 16dp;
}

/* Debug Controls Component */
.debug-controls {
    position: absolute;
    top: -20dp;
    right: 0dp;
    display: flex;
    gap: 3dp;
    z-index: 10;
}

.debug-btn {
    height: 20dp;
    padding: 0 4dp;
    cursor: pointer;
    text-align: center;
    line-height: 18dp;
    transition: all 0.1s;
}

.debug-btn:hover {
    transform: scale(1.1);
}

.debug-btn:active {
    transform: scale(0.95);
}

/* Header Component */
#widget-header {
    display: flex;
    flex-direction: row;
    justify-content: space-between;

    background-color: #4a4a4a00;
    text-align: center;
    color: white;
    border-bottom-width: 1px;
    border-bottom-color: white;

    padding-bottom: 1rem;
    margin-bottom: 1rem;
}

/* Tabs Component */
#tab-list {
    display: flex;
    flex-direction: row;

    background-color: #333;
}

.tab {
    cursor: pointer;
    text-align: center;
    padding: 4dp 8dp;
}

.tab:hover {
    color: #ebebeb;
}

/*
 * Table
 */
table {
	box-sizing: border-box;
	display: table;
}
tr {
	box-sizing: border-box;
	display: table-row;
}
td {
	box-sizing: border-box;
	display: table-cell;
}
col {
	box-sizing: border-box;
	display: table-column;
}
colgroup {
	display: table-column-group;
}
thead, tbody, tfoot {
	display: table-row-group;
}

/* === Rml Core Element Defaults === */
tabset tabs
{
	display: block;
}

/* Scrollbar */
scrollbarvertical,
scrollbarhorizontal
{
	width: 6dp;
}

scrollbarvertical slidertrack
{
	background-color: rgb(100, 100, 100);
    right: 0;
}

scrollbarvertical sliderbar,
scrollbarhorizontal sliderbar
{
	background-color: rgb(200, 200, 200);
	border-radius: 2dp;
}

sliderarrowinc:hover,
sliderarrowdec:hover
{
	background-color: rgb(150,150,150);
}

























]]
