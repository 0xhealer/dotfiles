import QtQuick 2.0

Rectangle {
    id: root
    width: 1280
    height: 720
    color: "#1e1e2e"

    property color accent: "#cba6f7"
    property color surface: "#d91e1e2e"
    property color text: "#cdd6f4"
    property int sessionIndex: sessionModel.lastIndex

    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: parent
        color: "#59000000"
    }

    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.12
        color: root.text
        font.pixelSize: 72
        font.bold: true
        text: Qt.formatTime(new Date(), "HH:mm")
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm")
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 380
        height: 250
        radius: 14
        color: root.surface
        border.color: root.accent
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 14
            width: parent.width - 60

            Rectangle {
                width: parent.width
                height: 42
                radius: 8
                color: "#33ffffff"
                TextInput {
                    id: userField
                    anchors.fill: parent
                    anchors.margins: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.text
                    font.pixelSize: 16
                    selectByMouse: true
                    text: userModel.lastUser
                    KeyNavigation.tab: passField
                    Keys.onReturnPressed: passField.forceActiveFocus()
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        color: "#99cdd6f4"
                        font.pixelSize: 16
                        text: "Username"
                        visible: !parent.text
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 42
                radius: 8
                color: "#33ffffff"
                border.color: passField.activeFocus ? root.accent : "transparent"
                border.width: 1
                TextInput {
                    id: passField
                    anchors.fill: parent
                    anchors.margins: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.text
                    font.pixelSize: 16
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    focus: true
                    KeyNavigation.backtab: userField
                    Keys.onReturnPressed: sddm.login(userField.text, passField.text, root.sessionIndex)
                    Keys.onEnterPressed: sddm.login(userField.text, passField.text, root.sessionIndex)
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        color: "#99cdd6f4"
                        font.pixelSize: 16
                        text: "Password"
                        visible: !parent.text
                    }
                }
            }

            Text {
                id: message
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "#f38ba8"
                font.pixelSize: 13
                text: ""
            }

            Row {
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: sessionModel
                    onItemAdded: {
                        if (index === root.sessionIndex && !item.visible)
                            root.sessionIndex = (index + 1) % sessionModel.count
                    }
                    Rectangle {
                        height: 30
                        width: label.width + 24
                        radius: 15
                        visible: model.name.indexOf("debug") < 0
                        color: index === root.sessionIndex ? root.accent : "#33ffffff"
                        Text {
                            id: label
                            anchors.centerIn: parent
                            font.pixelSize: 13
                            color: index === root.sessionIndex ? "#1e1e2e" : root.text
                            text: model.name
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.sessionIndex = index
                        }
                    }
                }
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 24
        spacing: 12
        Repeater {
            model: ["Suspend", "Reboot", "Power off"]
            Rectangle {
                height: 30
                width: act.width + 24
                radius: 15
                color: "#33ffffff"
                visible: index === 0 ? sddm.canSuspend : index === 1 ? sddm.canReboot : sddm.canPowerOff
                Text {
                    id: act
                    anchors.centerIn: parent
                    font.pixelSize: 13
                    color: root.text
                    text: modelData
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: index === 0 ? sddm.suspend() : index === 1 ? sddm.reboot() : sddm.powerOff()
                }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            message.text = "Wrong password"
            passField.text = ""
            passField.forceActiveFocus()
        }
    }

    Component.onCompleted: passField.forceActiveFocus()
}
