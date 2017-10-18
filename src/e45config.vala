using Gtk;

extern int open_serial(string dev, int baudrate);
extern void close_serial(int fd);


public class  E45Config : Object
{
    private uint8[] VERSION =  {0xc3, 0xc3, 0xc3};
    private uint8[] SETTINGS =  {0xc1, 0xc1, 0xc1};
    private Entry addr;
    private Entry chan;
    private Entry freq;
    private ComboBoxText parity_c;
    private ComboBoxText baud_c;
    private ComboBoxText air_rate_c;
    private ComboBoxText power_c;
    private ComboBoxText fec_c;
    private ComboBoxText txmode_c;
    private ComboBoxText iomode_c;
    private ComboBoxText wot_c;

    public E45Config()
    {
        var ser = new E45Serial();
        var         builder = new Gtk.Builder ();
        try
        {
            builder.add_from_resource ("/org/mwptools/e45/e45ui.ui");
            builder.connect_signals (null);
            var window = builder.get_object ("toplevel") as Window;
            var readdev = builder.get_object ("get_params_b") as Button;
            var writedev = builder.get_object ("set_params_b") as Button;
            var close = builder.get_object ("close_b") as Button;
            var dev  = builder.get_object ("dev_e") as Entry;
            var vers = builder.get_object ("vers_e") as Entry;
            var id = builder.get_object ("id_e") as Entry;
            var rawhex = builder.get_object ("raw_e") as Entry;
            addr = builder.get_object("address_e") as Entry;
            chan = builder.get_object("chan_e") as Entry;
            freq = builder.get_object("freq_e") as Entry;
            parity_c = builder.get_object("parity_c") as ComboBoxText;
            baud_c = builder.get_object("baud_c") as ComboBoxText;
            air_rate_c = builder.get_object("air_rate_c") as ComboBoxText;
            power_c = builder.get_object("power_c") as ComboBoxText;
            fec_c = builder.get_object("fec_c") as ComboBoxText;
            txmode_c = builder.get_object("txmode_c") as ComboBoxText;
            iomode_c = builder.get_object("iomode_c") as ComboBoxText;
            wot_c = builder.get_object("wot_c") as ComboBoxText;

            if (dev.text == null || dev.text.length == 0)
                dev.text = "/dev/ttyUSB0";

            close.clicked.connect (() => {
                    Gtk.main_quit();
                });

            readdev.clicked.connect(() => {
                    ser.issue_cmd(VERSION);
                });

            writedev.clicked.connect(() => {
                    write_settings(ser);
                });

            var s_open = builder.get_object ("open_b") as Button;
            s_open.clicked.connect (() => {
                    if(ser.fd == -1)
                    {
                        if(ser.open_port(dev.text, 9600))
                        {
                            readdev.sensitive = writedev.sensitive = true;
                            s_open.set_label("Disconnect");
                            ser.issue_cmd(VERSION);
                        }
                    }
                    else
                    {
                        ser.close();
                        s_open.set_label("Connect");
                        readdev.sensitive = writedev.sensitive = false;
                    }
                });

            ser.serial_lost.connect(() => {
                    ser.close();
                    s_open.set_label("Open");
                });

            ser.no_reply.connect(() => {
                    stderr.puts("No response from device\n");
                    var msg = new Gtk.MessageDialog.with_markup (window,
                                                                 0,
                                                                 MessageType.WARNING,
                                                                 ButtonsType.OK,
                                                                 "No response from device");
                    msg.response.connect ((response_id) => {
                            msg.destroy();
                        });
                    msg.set_title("E45Config Notice");
                    msg.show();
                });

            ser.serial_read.connect ((raw,len) => {
                    var rhex = dump_result(raw, len);
                    stderr.printf("Read [%s]\n", rhex);
                    rawhex.text = rhex;

                    switch(raw[0])
                    {
                        case 0xc0:
                        case 0xc2:
                            uint16 a;
                            a = raw[2] | raw[1]<<8;
                            var chn = raw[4] & 0x1f;

                            addr.text = "%u".printf(a);
                            chan.text = "%d".printf(chn);
                            freq.text = "%d MHz".printf(862+chn);

                            var par = raw[3] >> 6;
                            if(par == 3)
                                par = 0;
                            var brate = (raw[3] >> 3) & 7;
                            var airr = raw[3] & 7;
                            if(airr > 5)
                                airr = 5;

                            parity_c.set_active(par);
                            baud_c.set_active(brate);
                            air_rate_c.set_active(airr);

                            var txmode = raw[5] >> 7;
                            var iomode = (raw[5] >> 6) & 1;
                            var wot = (raw[5] >> 3) & 7;
                            var fec = (raw[5] >> 2) & 1;
                            var tpower = raw[5] & 3;

                            txmode_c.active = txmode;
                            iomode_c.active = iomode;
                            wot_c.active = wot;
                            fec_c.active = fec;
                            power_c.active = tpower;
                            break;
                        case 0xc1:
                            break;
                        case 0xc3:
                            id.text = "E%02x".printf(raw[1]);
                            vers.text = "%d.%d\t(%02x)".printf(raw[2]/10, raw[2] % 10, raw[3]);
                            Timeout.add(200, () => {
                                    ser.issue_cmd(SETTINGS);
                                    return Source.REMOVE;
                                });
                            break;
                        default:
                            stderr.puts("Unexpected\n");
                            break;
                    }
                });

            window.destroy.connect (Gtk.main_quit);
            window.show_all();
            Gtk.main();
        }
        catch {}
    }

    private void write_settings(E45Serial ser)
    {
        uint8 raw[6];
        raw[0] = 0xc0;
        uint16 a = (uint16)int.parse(addr.text);
        raw[1] = a >> 8;
        raw[2] = (uint8)(a & 0xff);
        raw[3] = (uint8)(air_rate_c.active | baud_c.active << 3 | parity_c.active << 6);
        raw[4] = (uint8)(int.parse(chan.text)) & 0x1f;
        raw[5] = (uint8)(power_c.active | fec_c.active << 2 | wot_c.active << 3 |
                         iomode_c.active << 6 | txmode_c.active << 7);
        var s = dump_result(raw, 6);
        stderr.printf("write set [%s]\n", s);
        ser.issue_cmd(raw, 6);
    }

    private string dump_result(uint8[]raw, uint len)
    {
        StringBuilder sb = new StringBuilder();
        for(var i = 0; i < len; i++)
            sb.append("%02x ".printf(raw[i]));
        return sb.str;
    }
}

public class E45Serial : Object
{
    public int fd {private set; get;}
    private IOChannel io_read;
    private uint8 rxbuf[8];
    private uint wanted;
    private uint inp;
    private uint tag;
    private uint tid;

    public signal void serial_lost ();
    public signal void no_reply ();
    public signal void serial_read (uint8[]result, uint len);

    public E45Serial()
    {
        fd = -1;
    }

    public bool open_port(string device, int baud)
    {
        var res = false;
        fd = open_serial(device, baud);
        if(fd != -1)
        {
            try {
                io_read = new IOChannel.unix_new(fd);
                if(io_read.set_encoding(null) != IOStatus.NORMAL)
                    error("Failed to set encoding");
                tag = io_read.add_watch(IOCondition.IN|IOCondition.HUP|
                                        IOCondition.NVAL|IOCondition.ERR,
                                        device_read);
            } catch(IOChannelError e) {
                error("IOChannel: %s", e.message);
            }
            res = true;
        }
        return res;
    }

    public void issue_cmd(uint8[] cmd, int len = -1)
    {
        inp = 0;
        wanted = (cmd[0] == 0xc3) ? 4 : 6;
        tid = Timeout.add_seconds(1, () => {
                tid = 0;
                no_reply();
                return Source.REMOVE;
            });

        int wlen = (len == -1) ? cmd.length : len;
        var n= Posix.write(fd, cmd, wlen);
        stderr.printf("Wrote cmd = %02x, len %lu, expect %u\n", cmd[0], n, wanted);
    }

    private bool device_read(IOChannel gio, IOCondition cond)
    {
        if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0)
        {
            print("Bad condition\n");
            if(fd != -1)
                serial_lost();
            return Source.REMOVE;
        }
        else if (fd != -1)
        {
            uint8 c = 0;
            var res = Posix.read(fd,&c, 1);
            if(res == 0)
                return Source.CONTINUE;
            rxbuf[inp++] = c;
            if(inp == wanted)
            {
                if(tid > 0)
                    Source.remove(tid);
                serial_read(rxbuf, inp);
                tid = 0;
            }
        }
        return Source.CONTINUE;
    }

    public void close()
    {
        if(fd != -1)
        {
            if(tag > 0)
            {
                Source.remove(tag);
                tag = 0;
            }
            close_serial(fd);
            fd = -1;
        }
    }
}

int main (string[] args)
{
    Gtk.init (ref args);
    new E45Config();
    return 0;
}
