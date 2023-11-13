using Dicom;
using Dicom.Network;
using DicomClient = Dicom.Network.Client.DicomClient;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace FoDicomCmdlets
{
  [Cmdlet("Move", "StudyByStudyInstanceUIDSync")]
  public class MoveStudyByStudyInstanceUIDCmdlet : Cmdlet
  {
    [Parameter(Mandatory = true)]
    public string StudyInstanceUID { get; set; }

    [Parameter(Mandatory = true)]
    public string DestinationAE { get; set; }

    [Parameter(Mandatory = true)]
    public string ServerHost { get; set; }

    [Parameter(Mandatory = true)]
    public int ServerPort { get; set; }

    [Parameter(Mandatory = true)]
    public string MyAE { get; set; }

    [Parameter(Mandatory = true)]
    public string ServerAE { get; set; }

    protected override void ProcessRecord()
    {
      var request = new DicomCMoveRequest(DestinationAE, StudyInstanceUID);
      var client = new DicomClient(ServerHost, ServerPort, false, MyAE, ServerAE);

      var responses = new List<DicomCMoveResponse>();

      request.OnResponseReceived += (req, response) =>
      {
        responses.Add(response);
      };

      client.AddRequestAsync(request).GetAwaiter().GetResult();
      client.SendAsync().GetAwaiter().GetResult();

      WriteObject(responses);
    }
  }
}
