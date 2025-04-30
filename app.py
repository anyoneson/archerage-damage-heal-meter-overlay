import json
import os
import re
import sys
from PyQt5.QtWidgets import QMessageBox, QCheckBox, QComboBox, QColorDialog, QDialog, QApplication, QWidget, QLabel, QLineEdit, QVBoxLayout, QHBoxLayout, QPushButton, QScrollArea, QGridLayout
from PyQt5.QtCore import QTimer, Qt
from PyQt5.QtGui import QFont
from datetime import datetime, timedelta
from typing import List, Optional

DEFAULT_LOG_TYPES = ['damage', 'heal']

with open('config.json', 'r') as f:
    config = json.load(f)
    
# Check if the log file exists
if not os.path.exists(config['logFilePath']):
    app = QApplication(sys.argv)
    error_message = f"Log file '{config['logFilePath']}' does not exist. Check the logFilePath value in config.json file and fix it before running."
    # Create a QMessageBox to display the error message
    msg = QMessageBox()
    msg.setIcon(QMessageBox.Critical)
    msg.setText("Error")
    msg.setInformativeText(error_message)
    msg.setWindowTitle("Configuration Error")
    msg.exec_()
    sys.exit(1)

LOG_FILE_PATH = config['logFilePath']
LOG_TIME = config.get('logMinutesAgo') if config.get('logMinutesAgo') else 60
LOG_TYPE = config.get('logType') if config.get('logType') else "damage"
TARGET_NAME = config.get('targetName')
OVERLAY_WIDTH = config['overlayWidth'] if config.get('overlayWidth') else 300
OVERLAY_HEIGHT = config['overlayHeight'] if config.get('overlayWidth') else 300
OVERLAY_OPACITY = config['overlayOpacity'] if config.get('overlayOpacity') else "30%"
OVERLAY_LOG_COLOR = config['overlayLogColor'] if config.get('overlayLogColor') else "lime"
OVERLAY_POSITION = config.get('overlayPosition') if config.get('overlayPosition') else [30, 30]
OVERLAY_FONT_SIZE =  config.get('overlayFontSize') if config.get('overlayFontSize') else 20
OVERLAY_LOGS_FONT_SIZE =  config.get('overlayLogsFontSize') if config.get('overlayLogsFontSize') else 10


initial_time_filter = ""
minimize_state = False
scrollbar = None
frame = None
first_exec = True
selected_log_color = OVERLAY_LOG_COLOR
window_mode_state = False

def openColorDialog():
    global selected_log_color
    
    color = QColorDialog.getColor()

    if color.isValid():
        selected_log_color = color.name()
        
def toggle_mode():
    global window_mode_state
    
    if window_mode_state:
        window_mode_state = False
        add_frameless_window_hint()
        return
    window_mode_state = True
    remove_frameless_window_hint()
    
def set_time_toggle():
    global initial_time_filter
    initial_time_filter = datetime.now()
    # Update the overlay
    update_overlay()
            
def configure():
    # Use the global variables
    global LOG_FILE_PATH, TARGET_NAME, LOG_TIME, DEFAULT_LOG_TYPES, config_window_state, initial_time_filter, OVERLAY_FONT_SIZE, OVERLAY_LOGS_FONT_SIZE

    # Create a dialog to ask for the configuration values
    dialog = QDialog()
    dialog.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
    dialog.setWindowTitle("Settings")
    dialog.setMinimumWidth(300)
    dialog.setFont(QFont('Roboto', OVERLAY_FONT_SIZE))
    dialog.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;color: white; background-color: rgba( 0, 0, 0, 10%  );")

    # Create the labels and line edits for the configuration values
    label_log_path = QLabel("Log file path:")
    edit_log_path = QLineEdit(LOG_FILE_PATH)
    
    label_overlay_width = QLabel("Overlay width:")
    edit_overlay_width = QLineEdit(str(OVERLAY_WIDTH))    
    
    label_overlay_height = QLabel("Overlay height:")
    edit_overlay_height = QLineEdit(str(OVERLAY_HEIGHT))
    
    label_overlay_font_size = QLabel("Overlay font size:")
    edit_overlay_font_size = QLineEdit(str(OVERLAY_FONT_SIZE))
    
    label_overlay_logs_font_size = QLabel("Overlay logs font size:")
    edit_overlay_logs_font_size = QLineEdit(str(OVERLAY_LOGS_FONT_SIZE))
    
    label_overlay_opacity = QLabel("Overlay opacity %:")
    edit_overlay_opacity = QLineEdit(str(OVERLAY_OPACITY))

    label_target_name = QLabel("Target name:")
    edit_target_name = QLineEdit(TARGET_NAME)
    
    label_initial_time = QLabel("Initial time filter:")
    edit_initial_time = QLineEdit(str(initial_time_filter))

    label_minutes_ago = QLabel("Minutes ago:")
    edit_minutes_ago = QLineEdit(str(LOG_TIME))

    label_log_type = QLabel("Log type:")
    combobox_log_type = QComboBox()
    combobox_log_type.addItems(DEFAULT_LOG_TYPES)
    combobox_log_type.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;color: black; background-color: rgba( 255, 255, 255, 50%  );")
    if LOG_TYPE == 'heal':
        combobox_log_type.setCurrentIndex(1)
    
    label_log_color = QLabel("Log color:")
    button_color_picker = QPushButton('Select color')
    button_color_picker.clicked.connect(openColorDialog)
    button_color_picker.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;color: black; background-color: rgba( 255, 255, 255, 50%  );")

    label_change_position = QLabel("Window mode:")
    change_position_button = QCheckBox("Change")
    change_position_button.setCheckable(True)
    change_position_button.clicked.connect(toggle_mode)
    change_position_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;color: black; background-color: rgba( 255, 255, 255, 50%  );")

    # Create the OK and Cancel buttons
    ok_button = QPushButton("OK")
    ok_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;color: black; background-color: rgba( 255, 255, 255, 50%  );")
    
    cancel_button = QPushButton("Cancel")
    cancel_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;color: black; background-color: rgba( 255, 255, 255, 50%  );")


    # Create a layout for the dialog
    layout = QGridLayout()
    
    # Create a label for the Settings text
    setting_label = QLabel("Settings")
    setting_label.setAlignment(Qt.AlignLeft)
    layout.addWidget(setting_label, 0, 0)
    
    # Create a label for the "by Xizde" text
    by_label = QLabel("by Xizde")
    by_label.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;color: {OVERLAY_LOG_COLOR};")
    by_label.setAlignment(Qt.AlignRight)
    layout.addWidget(by_label, 0, 1)

    # Add the labels and line edits to the layout
    layout.addWidget(label_log_path, 1, 0)
    layout.addWidget(edit_log_path, 1, 1)
    
    layout.addWidget(label_overlay_width, 2, 0)
    layout.addWidget(edit_overlay_width, 2, 1)
    
    layout.addWidget(label_overlay_height, 3, 0)
    layout.addWidget(edit_overlay_height, 3, 1)
    
    layout.addWidget(label_overlay_font_size, 4, 0)
    layout.addWidget(edit_overlay_font_size, 4, 1)  
    
    layout.addWidget(label_overlay_logs_font_size, 5, 0)
    layout.addWidget(edit_overlay_logs_font_size, 5, 1)  
    
    layout.addWidget(label_overlay_opacity, 6, 0)
    layout.addWidget(edit_overlay_opacity, 6, 1)  
      
    layout.addWidget(label_log_type, 7, 0)
    layout.addWidget(combobox_log_type, 7, 1)

    layout.addWidget(label_target_name, 8, 0)
    layout.addWidget(edit_target_name, 8, 1)
    
    layout.addWidget(label_initial_time, 9, 0)
    layout.addWidget(edit_initial_time, 9, 1)

    layout.addWidget(label_minutes_ago, 10, 0)
    layout.addWidget(edit_minutes_ago, 10, 1)
    
    layout.addWidget(label_log_color, 11, 0)
    layout.addWidget(button_color_picker, 11, 1)
    
    layout.addWidget(label_change_position, 12, 0)
    layout.addWidget(change_position_button, 12, 1)

    # Add the OK and Cancel buttons to the layout
    layout.addWidget(ok_button, 13, 0)
    layout.addWidget(cancel_button, 13, 1)

    # Set the layout for the dialog
    dialog.setLayout(layout)

    # Set the focus to the OK button
    ok_button.setFocus()

    # Connect the OK and Cancel buttons to their respective functions
    ok_button.clicked.connect(lambda: apply_settings(dialog, edit_log_path, edit_target_name, edit_minutes_ago, edit_overlay_width, edit_overlay_height, edit_overlay_opacity, combobox_log_type.currentText(), edit_initial_time, edit_overlay_font_size, edit_overlay_logs_font_size))
    cancel_button.clicked.connect(dialog.reject)

    # Show the dialog
    dialog.exec_()
    
def exit_application():
    app.quit()

def apply_settings(dialog, edit_log_path, edit_target_name, edit_minutes_ago, edit_overlay_width, edit_overlay_height, edit_overlay_opacity, combobox_log_type, edit_initial_time, edit_overlay_font_size, edit_overlay_logs_font_size):
    # Use the global variables
    global LOG_FILE_PATH, TARGET_NAME, LOG_TIME, OVERLAY_HEIGHT, OVERLAY_WIDTH, OVERLAY_FONT_SIZE
    global OVERLAY_OPACITY, OVERLAY_LOG_COLOR, selected_log_color, LOG_TYPE, OVERLAY_POSITION, initial_time_filter
    global OVERLAY_LOGS_FONT_SIZE

    # Update the configuration values
    LOG_FILE_PATH = edit_log_path.text()
    TARGET_NAME = edit_target_name.text()
    LOG_TIME = int(edit_minutes_ago.text())
    LOG_TYPE = combobox_log_type if combobox_log_type else LOG_TYPE
    OVERLAY_HEIGHT = int(edit_overlay_height.text())
    OVERLAY_WIDTH = int(edit_overlay_width.text())
    OVERLAY_OPACITY = edit_overlay_opacity.text()
    OVERLAY_LOG_COLOR = selected_log_color
    OVERLAY_POSITION = [window.pos().x(), window.pos().y()] if window.pos() else OVERLAY_POSITION
    OVERLAY_FONT_SIZE = int(edit_overlay_font_size.text()) if edit_overlay_font_size.text() else OVERLAY_FONT_SIZE
    OVERLAY_LOGS_FONT_SIZE = int(edit_overlay_logs_font_size.text()) if edit_overlay_logs_font_size.text() else OVERLAY_LOGS_FONT_SIZE
    
    if not edit_initial_time.text():
        initial_time_filter = None
        
    # Save new settings
    with open('config.json', 'w') as f:
        config = json.dumps({
            "overlayPosition": OVERLAY_POSITION,
            "overlayWidth": OVERLAY_WIDTH,
            "overlayHeight": OVERLAY_HEIGHT,
            "overlayFontSize": OVERLAY_FONT_SIZE,
            "overlayLogsFontSize": OVERLAY_LOGS_FONT_SIZE,
            "overlayOpacity": OVERLAY_OPACITY,
            "overlayLogColor": OVERLAY_LOG_COLOR,
            "logFilePath": LOG_FILE_PATH,
            "logMinutesAgo": LOG_TIME,
            "targetName": TARGET_NAME if TARGET_NAME else "",
            "logType": LOG_TYPE
        }, indent=4)
        f.write(config)
        f.close()
        
    # Close the dialog
    dialog.accept()

def update_widgets_opacity():
    global exit_button, config_button, minimize_button, previous_geometry, scroll_area
    
    # window buttons
    config_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
    exit_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
    minimize_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
    maximize_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
    reset_log_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
    # scroll area
    scroll_area.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY}%  ); color: white;" );
    
    
def extract_attack_data(log_file_path: str, minutes_ago: int = 60, target_name: Optional[str] = None):
    # Compile regex pattern that matches all damage formats
    pattern = re.compile(r"<(?P<log_time_str>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?P<character>.*?)\|r attacked (?P<receiver>.*?)\|r(?: using \|cff57d6ae(.*?)\|r)? and caused \|cffc13d36\-(?P<total>\d+)\|r")
    # Calculate time range
    minutes_ago_time = timedelta(minutes=minutes_ago)
    end_time = datetime.now()
    if initial_time_filter:
        start_time = initial_time_filter
    else:
        start_time = end_time - minutes_ago_time
        

    # Use generator expression to yield attack data
    with open(log_file_path, "r", encoding="utf8") as f:
        yield from (
            {"timestamp": log_time_str, "character": character, "target": receiver, "total": total}
            for line in f
            if "attacked" in line
            for match in [pattern.search(line)]
            if match
            for log_time_str, character, receiver, _, total in [match.groups()] 
            if log_time_str is not None
            if start_time <= datetime.strptime(log_time_str, "%Y-%m-%d %H:%M:%S") <= end_time
            if not target_name or receiver == target_name
        )

def extract_heal_data(log_file_path: str, minutes_ago: int = 60, target_name: Optional[str] = None):
    pattern = re.compile(r"<(?P<log_time_str>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?P<character>.*?)\|r targeted (?P<receiver>[^|]+)\|[^|]+\|cff25fcff(?P<ability>[^|]+)\|[^|]+\|cff00ff00(?P<restored>[^|]+)\|r health.")

    # Calculate time range
    minutes_ago_time = timedelta(minutes=minutes_ago)
    end_time = datetime.now()
    if initial_time_filter:
        start_time = initial_time_filter
    else:
        start_time = end_time - minutes_ago_time
    
    with open(log_file_path, "r", encoding="utf8") as f:
        yield from (
            {"timestamp": log_time_str, "character": character, "target": receiver, "total": total}
            for line in f
            if "targeted" in line 
            for match in [pattern.search(line)]
            if match
            for log_time_str, character, receiver, _, total in [match.groups()]
            if log_time_str is not None
            if start_time <= datetime.strptime(log_time_str, "%Y-%m-%d %H:%M:%S",) <= end_time
            if not target_name or receiver == target_name
        )
        
def format_number(n) -> str:
    if str(n).lower() in DEFAULT_LOG_TYPES:
        return n
    
    suffixes = ['', 'k', 'M', 'B', 'T']
    i = 0
    while n >= 1000 and i < len(suffixes)-1:
        n /= 1000.0
        i += 1
    if i == 0:
        return str(int(n))
    else:
        return str('{:,.1f}{}'.format(n, suffixes[i]))
    
# Function to update the overlay with the new configuration
def update_overlay():
    # Use the global variables
    global LOG_FILE_PATH, TARGET_NAME, LOG_TIME, scroll_content_layout, minimize_state, previous_geometry
    global first_exec, LOG_TYPE, window_mode_state, OVERLAY_FONT_SIZE
    update_widgets_opacity()
    
    if first_exec:
        minimize_state = True
        first_exec = False
       
    if not window_mode_state:     
        window.move(OVERLAY_POSITION[0], OVERLAY_POSITION[1])
        
    #window.setFont(QFont('Roboto', OVERLAY_FONT_SIZE))
        
    if not minimize_state:    
        QTimer.singleShot(10, update_overlay)  # update every minute
    else:
        window.resize(OVERLAY_WIDTH, OVERLAY_HEIGHT)
        
        # Extract damage / heal based on config LOG_TYPE
        if LOG_TYPE == "damage":
            data_logs = extract_attack_data(log_file_path=LOG_FILE_PATH, minutes_ago=LOG_TIME, target_name=TARGET_NAME)
        elif LOG_TYPE == "heal":
            data_logs = extract_heal_data(log_file_path=LOG_FILE_PATH, minutes_ago=LOG_TIME, target_name=TARGET_NAME)

        # Aggregate the data by attacker
        damage_data = {}
        for log in data_logs:
            character = log["character"]
            if log["total"]:
                total = int(log["total"].replace(",", ""))

            damage_data[character] = damage_data.get(character, 0) + total

        # Sort the data by total in descending order
        sorted_data = sorted(damage_data.items(), key=lambda x: x[1], reverse=True)

        # Clear the layout
        while scroll_content_layout.count():
            child = scroll_content_layout.takeAt(0)
            if child.widget():
                child.widget().deleteLater()

        # Setting titles
        sorted_data.insert(0, ("Rank - Name", LOG_TYPE.capitalize()))

        # Display the first 5 rows of sorted data
        for i, (attacker, total) in enumerate(sorted_data):
            label_attacker = QLabel(str(f'{i} {attacker}'))
            if attacker == 'Rank - Name':
                label_attacker = QLabel(str(attacker))
                label_attacker.setFont(QFont('Roboto', OVERLAY_LOGS_FONT_SIZE))
                label_attacker.setStyleSheet(f"font-family: 'Roboto'; font-size: {OVERLAY_LOGS_FONT_SIZE}px;color: white; background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY}%  );")
            else:
                label_attacker.setFont(QFont('Roboto', OVERLAY_LOGS_FONT_SIZE))
                label_attacker.setStyleSheet(f"font-family: 'Roboto'; font-size: {OVERLAY_LOGS_FONT_SIZE}px;color: {OVERLAY_LOG_COLOR}; background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY}%  );")

            
            label_total = QLabel(format_number(total))
            label_total.setFont(QFont('Roboto', OVERLAY_LOGS_FONT_SIZE))
            if str(total).lower() in DEFAULT_LOG_TYPES:
                label_total.setStyleSheet(f"font-family: 'Roboto'; font-size: {OVERLAY_LOGS_FONT_SIZE}px;color: white; background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY}%  );")
            else:
                label_total.setStyleSheet(f"font-family: 'Roboto'; font-size: {OVERLAY_LOGS_FONT_SIZE}px;color: {OVERLAY_LOG_COLOR}; background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY}%  );")
                
            scroll_content_layout.addWidget(label_attacker, i, 0)
            scroll_content_layout.addWidget(label_total, i, 1)
        
        update_widgets_opacity()
        # Schedule the next update
        QTimer.singleShot(10000, update_overlay)  # update every minute

def minimize_maximize_overlay():
    global window, minimize_state, scroll_area, previous_geometry, exit_button, config_button, minimize_button, maximize_button, reset_log_button
    
    if minimize_state:
        # Save the previous window geometry
        previous_geometry = window.geometry()
        
        # Hide the scroll area and set the window height to 1
        scroll_area.hide()
        exit_button.setVisible(not minimize_state)
        config_button.setVisible(not minimize_state)
        minimize_button.setVisible(not minimize_state)
        reset_log_button.setVisible(not minimize_state)
        maximize_button.setVisible(True)
        window.resize(20, 20)
        minimize_state = False
    elif not minimize_state:   
        # Restore the previous window geometry
        window.setGeometry(previous_geometry)
        
        # Show the scroll area
        scroll_area.show()
        
        exit_button.setVisible(not minimize_state)
        config_button.setVisible(not minimize_state)
        minimize_button.setVisible(not minimize_state)
        reset_log_button.setVisible(not minimize_state)
        maximize_button.setVisible(False)
        minimize_state = True
    
    # Update the overlay
    update_overlay()
        
def remove_frameless_window_hint():
    global window
    flags = window.windowFlags()
    flags &= ~Qt.FramelessWindowHint
    window.setWindowFlags(flags)
    window.show()
    
def add_frameless_window_hint():
    global window
    window.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
    window.show()


# enable high DPI scaling
QApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
QApplication.setAttribute(Qt.AA_UseHighDpiPixmaps, True)

# Create the GUI window
app = QApplication(sys.argv)

window = QWidget()
window.setGeometry(30, 30, OVERLAY_WIDTH, OVERLAY_HEIGHT)
previous_geometry = window.geometry()
window.setWindowTitle("ArcheRage - Damage/Heal Meter")

window.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
window.setAttribute(Qt.WA_NoSystemBackground, True)
window.setAttribute(Qt.WA_TranslucentBackground, True)

# Create a vertical layout for the main window
layout = QVBoxLayout()
window.setLayout(layout)

# Create a horizontal layout for the buttons
button_layout = QGridLayout()

# Create the Configuration button
minimize_button = QPushButton("-")
minimize_button.setFont(QFont('Roboto', 8))
minimize_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
minimize_button.clicked.connect(minimize_maximize_overlay)
button_layout.addWidget(minimize_button, 0,0)

# Create the Configuration button
reset_log_button = QPushButton("Set time")
reset_log_button.setFont(QFont('Roboto', 8))
reset_log_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
reset_log_button.clicked.connect(set_time_toggle)
button_layout.addWidget(reset_log_button, 0,1)

# Create the Exit button
exit_button = QPushButton("Exit")
exit_button.setFont(QFont('Roboto', 8))
exit_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
exit_button.clicked.connect(exit_application)
button_layout.addWidget(exit_button, 1,0)

# Create the Configuration button
config_button = QPushButton("Settings")
config_button.setFont(QFont('Roboto', 8))
config_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
config_button.clicked.connect(configure)
button_layout.addWidget(config_button, 1,1)

# Add the button layout to the main layout
layout.addLayout(button_layout)

# Create the Configuration button
maximize_button = QPushButton("+")
maximize_button.setFont(QFont('Roboto', 8))
maximize_button.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY if int(OVERLAY_OPACITY) > 0 else 1}%  ); color: white;" );
maximize_button.clicked.connect(minimize_maximize_overlay)
maximize_button.setVisible(False)
layout.addWidget(maximize_button)
    
# Create a scroll area for the data
scroll_area = QScrollArea()
scroll_content = QWidget()
scroll_content_layout = QGridLayout()
scroll_content.setLayout(scroll_content_layout)
scroll_area.setStyleSheet(f"font-size: {OVERLAY_FONT_SIZE}px;background-color: rgba( 0, 0, 0, {OVERLAY_OPACITY}% );" );

scroll_area.setWidget(scroll_content)
scroll_area.setWidgetResizable(True)

layout.addWidget(scroll_area)

# Schedule the first update
QTimer.singleShot(0, update_overlay)

# Show the window and start the event loop
window.show()
add_frameless_window_hint()

sys.exit(app.exec_())