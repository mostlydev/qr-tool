using Dicom;
using Dicom.Network;
using System;
using System.Management.Automation;

namespace FoDicomCmdlets
{
  [Cmdlet("Move", "StudyByStudyInstanceUID")]
  public class MoveStudyByStudyInstanceUIDCmdlet : Cmdlet
  {
    protected override void ProcessRecord()
    {
      Console.WriteLine("MoveStudyByStudyInstanceUIDCmdlet happened.");
    }
  }
}
