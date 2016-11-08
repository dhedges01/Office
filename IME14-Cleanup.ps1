$regPath = @("HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
)
$regName = "IME14*"

Remove-ItemProperty $regPath -Name $regName -Force