Facter.add(:has_x11) do
  confine :operatingsystem => :darwin
  setcode do
    File.exists?('/opt/X11/bin/x') || system('/usr/bin/which x')
  end
end
