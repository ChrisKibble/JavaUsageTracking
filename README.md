# JavaUsageTracking
Setup Java Usage Tracking in WMI for Easy Import into Configuration Manager

# Credit
This work was based almost entirely on work by Steve Jesok as published in his blog [here]( 
https://mnscug.org/blogs/steve-jesok/390-java-7-end-of-life-java-software-metering).

The original upload into this repo will be his original script as-is.  You can follow along in the repository for what changed I've made, and please feel free to submit your own pull requests if you have ways to make it better.

In the original script, Steve calls out additional credit to Ian Farr for his work on the [Log-ScriptEvent function](https://gallery.technet.microsoft.com/scriptcenter/Log-ScriptEvent-Function-ea238b85).

# Usage
While you can run this script on its own, the original purpose was to be run as a Configuration Manager Baseline Configuration Item.  Instructions on how to use this are available from System Center Dudes in [this blog post](https://www.systemcenterdudes.com/sccm-java-inventory-and-metering/).  From there you can download the  CAB with the original script included.  You could leave it as-is, or can replace the script with the community modified one here.
