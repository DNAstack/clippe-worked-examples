from enum import Enum


class StyleSheet(Enum):

    def __getattr__(self, item):
        if item != '_value_':
            return getattr(self.value, item).value
        raise AttributeError

    class title(Enum):
        color = '#13131E'
        font = 'Poppins, Semibold'
        font_size = 20

    class yaxis_title(Enum):
        color = '#525965'
        font = 'Poppins, Medium'
        font_size = 14

    class xaxis_title(Enum):
        color = '#525965'
        font = 'Poppins, Medium'
        font_size = 14

    class annotation(Enum):
        color = '#525965'
        font = 'Roboto, Medium'
        font_size = 14

    class plot(Enum):
        red = '#F64662'
        black = '#525965'
        single_color = '#5EBCD2'
        primary_color = '#85CBCF'
        secondary_color = '#3984B6'
        color_scale_1 = ['#B3E5FC', '#81D4FA', '#80D8FF', '#40C4FF', '#4FC3F7', '#29B6F6', '#00B0FF', '#03A9F4', '#039BE5', '#0091EA', '#0288D1', '#0277BD', '#015795']
        color_scale_2 = ['#DCECC9', '#B3DDCC', '#8ACDCE', '#62BED2', '#46AACE', '#3D91BE', '#3577AE', '#2D5E9E', '#24448E', '#1C2B7F', '#162065', '#11174B']

    class gridline(Enum):
        color = '#E9EBEF'

    class axes(Enum):
        color = '#969DAC'
