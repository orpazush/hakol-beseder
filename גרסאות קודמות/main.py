"""                 Polling Guard
                    Written by Orpaz Mizrachi
                    Last Update: 25.8.22
"""
import kivy
from kivy.app import App
from kivy.uix.gridlayout import GridLayout
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.widget import Widget

kivy.require("2.1.0")
__version__ = "1.00"


class LoginScreen(GridLayout):
    def __init__(self, **kwargs):
        super(LoginScreen, self).__init__(**kwargs)
        self.cols = 2
        self.add_widget(Label(text='User Name'))
        self.username = TextInput(multiline=False)
        self.add_widget(self.username)
        self.add_widget(Label(text='password'))
        self.password = TextInput(password=True, multiline=False)
        self.add_widget(self.password)


class GuardApp(App):
    def build(self):
        return LoginScreen()


guard = GuardApp()
guard.run()
