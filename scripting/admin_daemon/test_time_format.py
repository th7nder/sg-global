secs = 3680
hours = int((secs / 60) / 60)
minutes = int((secs / 60) % 60)
s = int((secs % 60) % 60)
print(hours, minutes, s)